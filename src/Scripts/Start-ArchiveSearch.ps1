<#
.SYNOPSIS
  Archive-only Compliance Search (Exchange Online / Purview) - cross-platform (Linux/macOS/Windows, PowerShell 7+)
.DESCRIPTION
  Retrieves Online Archive folders for a mailbox, converts FolderId (EWS Base64) to valid IndexId HEX for KQL,
  builds 'folderid:HEX OR ...' queries, partitions them if necessary, creates and executes Compliance Search(es)
  that return exclusively the archive content. Optional export.
  
  [AUTO-GENERATED]: Refactored to use ExchangeAdminTools module.
.NOTES
  Requirements: PowerShell 7+ (pwsh), ExchangeOnlineManagement module, Exchange and eDiscovery/Compliance permissions.
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$UserUpn,                        # E.g. user@domain.com

  [string]$BaseSearchName = $null,         # If null, generated from $UserUpn

  [int]$MaxQueryLength = 9000,             # Safe limit for KQL (adjust if your tenant requires less)

  [bool]$ExcludeDumpster = $true,          # Exclude Recoverable Items from Archive

  [bool]$KickOffExport = $false,           # Start export after each search completes

  [bool]$ExportIncludeUnsearchable = $true # Include Unsearchable Items in export
)

# ----------------- MODULE AUTO-LOADING -----------------
. $PSScriptRoot/_Bootstrap.ps1
# -------------------------------------------------------

# ---------- Utilities (Module handles Connect and Ensure-Module) ----------
function Test-HasCommand { param([string]$Name) return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue) }

# Converts EWS FolderId (Base64) to KQL IndexId HEX: 'folderid:HEX...'
function Convert-EwsFolderIdToKqlHex {
  param([Parameter(Mandatory = $true)][string]$EwsFolderId)

  # HEX ASCII Bytes
  $encoding = [System.Text.Encoding]::GetEncoding("us-ascii")
  $hexTable = $encoding.GetBytes("0123456789ABCDEF")

  # Decode Base64
  $bytes = [Convert]::FromBase64String($EwsFolderId)

  # Skip 23 header bytes and take 24 bytes of IndexId (EWS/IndexId rule)
  $payload = $bytes | Select-Object -Skip 23 -First 24
  if ($payload.Count -lt 24) {
    throw "EWS FolderId does not have enough length to extract IndexId (Id: $EwsFolderId)"
  }

  # Map to 48 HEX characters
  $out = New-Object byte[] 48
  $i = 0
  foreach ($b in $payload) {
    $out[$i++] = $hexTable[$b -shr 4]
    $out[$i++] = $hexTable[$b -band 0x0F]
  }
  return $encoding.GetString($out)  # 48 chars 0-9A-F
}

# Builds KQL from a list of EWS FolderIds (Base64) from the archive
function Build-KqlFromArchiveFolders {
  param([Parameter(Mandatory = $true)][string[]]$EwsFolderIds)
  $clauses = @()
  foreach ($ewsId in $EwsFolderIds) {
    try {
      $hex = Convert-EwsFolderIdToKqlHex -EwsFolderId $ewsId
      $clauses += "folderid:$hex"  # 'folderid:' must be lowercase
    }
    catch {
      Write-Warning "Could not convert a FolderId. Detail: $_"
    }
  }
  if (-not $clauses -or $clauses.Count -eq 0) {
    throw "Could not build KQL (folderid list empty)."
  }
  return ($clauses -join " OR ")
}

# ---------- Search Name ----------
if (-not $BaseSearchName) {
  $sanitized = $UserUpn -replace '[^a-zA-Z0-9_.-]', '_'
  $BaseSearchName = "ArchiveOnly_$sanitized"
}

# ---------- Connections: EXO and Purview ----------
# Use Shared Module Connect
Connect-Exchange

# Purview / Security & Compliance
if (-not (Test-HasCommand "Get-ComplianceSearch")) {
  Write-Host "Connecting to Security & Compliance (Connect-IPPSSession)..."
  try { Connect-IPPSSession -ErrorAction Stop } catch { throw "Failed to load Purview cmdlets (Get/New/Start-ComplianceSearch...). Detail: $_" }
}
else { Write-Verbose "Compliance cmdlets already available." }

# ---------- Mailbox and Archive Validation ----------
try { $mailbox = Get-Mailbox -Identity $UserUpn -ErrorAction Stop } catch { throw "Could not retrieve mailbox $UserUpn. Error: $_" }
if (-not $mailbox.ArchiveStatus -or $mailbox.ArchiveStatus -eq "None") {
  throw "User $UserUpn does not have Online Archive enabled (ArchiveStatus: $($mailbox.ArchiveStatus))."
}

# ---------- Archive Folders ----------
try {
  $archiveFolders = Get-MailboxFolderStatistics -Identity $UserUpn -Archive -ErrorAction Stop
}
catch {
  throw "Failed to execute Get-MailboxFolderStatistics -Archive: $_"
}

if ($ExcludeDumpster) {
  $archiveFolders = $archiveFolders | Where-Object {
    $_.FolderType -notlike "RecoverableItems*" -and $_.Name -notlike "Recoverable Items*"
  }
}

$folderIds = $archiveFolders | Where-Object { $_.FolderId } | Select-Object -ExpandProperty FolderId -Unique
if (-not $folderIds -or $folderIds.Count -eq 0) { throw "No FolderIds found in Archive for $UserUpn (after filtering)." }

Write-Host "Total folders in Archive: $($folderIds.Count)."

# ---------- Portable Temp Directory ----------
try {
  $tmp = [System.IO.Path]::GetTempPath(); if (-not $tmp) { $tmp = "/tmp" }
  $kqlOutDir = Join-Path $tmp ("ArchiveOnlyKql_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
  New-Item -ItemType Directory -Path $kqlOutDir -Force | Out-Null
  Write-Host "KQLs will be saved to: $kqlOutDir"
}
catch { throw "Could not create temp directory: $_" }

# ---------- Partitioning by Length ----------
$chunks = New-Object System.Collections.Generic.List[object]
$current = New-Object System.Collections.Generic.List[string]

foreach ($id in $folderIds) {
  $testArr = @($current + $id)
  try { $test = Build-KqlFromArchiveFolders -EwsFolderIds $testArr } catch { $test = "" }
  if ($test.Length -gt $MaxQueryLength -and $current.Count -gt 0) {
    $chunks.Add($current.ToArray())
    $current = New-Object System.Collections.Generic.List[string]
  }
  $current.Add($id)
}
if ($current.Count -gt 0) { $chunks.Add($current.ToArray()) }

Write-Host "Will generate $($chunks.Count) search(es)."

# ---------- Create and Execute Compliance Searches ----------
$results = @()

for ($idx = 0; $idx -lt $chunks.Count; $idx++) {
  $part = $chunks[$idx]
  $kql = Build-KqlFromArchiveFolders -EwsFolderIds $part
  $searchName = if ($chunks.Count -gt 1) { "$BaseSearchName`_part$($idx+1)" } else { $BaseSearchName }

  # Save KQL for audit
  $kqlFile = Join-Path $kqlOutDir "$searchName.kql.txt"
  try { $kql | Out-File -FilePath $kqlFile -Encoding UTF8 -Force } catch { Write-Warning "Could not write ${kqlFile}: $_" }

  # clean previous search if exists
  try {
    $existing = Get-ComplianceSearch -Identity $searchName -ErrorAction SilentlyContinue
    if ($existing) {
      Write-Host "Removing previous search '$searchName'..."
      Remove-ComplianceSearch -Identity $searchName -Confirm:$false -ErrorAction SilentlyContinue
    }
  }
  catch { Write-Warning "Warning removing existing search: $_" }

  # Create and Start
  try {
    Write-Host "Creating ComplianceSearch '$searchName'..."
    New-ComplianceSearch -Name $searchName -ExchangeLocation $UserUpn -ContentMatchQuery $kql -ErrorAction Stop | Out-Null
    Start-ComplianceSearch -Identity $searchName -ErrorAction Stop | Out-Null
  }
  catch { throw "Error creating/starting ComplianceSearch '$searchName': $_" }

  # Polling until completion with TIMEOUT
  $state = ""
  $startTime = Get-Date
  $timeoutSeconds = 3600 # 1 Hour Timeout

  do {
    Start-Sleep -Seconds 5
    
    if ((Get-Date) -gt $startTime.AddSeconds($timeoutSeconds)) {
      throw "Timeout waiting for search '$searchName' to complete."
    }

    try {
      $info = Get-ComplianceSearch -Identity $searchName -ErrorAction Stop
      $state = $info.Status
      Write-Host "$searchName -> State: $state  Items: $($info.Items)  Size: $($info.Size)"
    }
    catch {
      Write-Host "$searchName -> State: (not available yet)"; $state = ""
    }
  } until ($state -in @("Completed", "PartiallySucceeded", "Failed"))

  $info = Get-ComplianceSearch -Identity $searchName
  $results += $info

  if ($KickOffExport) {
    try {
      Write-Host "Starting export for $searchName..."
      $null = New-ComplianceSearchAction -SearchName $searchName -Export `
        -Format FxStream `
        -EnableDedupe:$true `
        -Scope Both `
        -IncludeUnsearchableItems:$ExportIncludeUnsearchable -ErrorAction Stop
      Write-Host "Export started for $searchName (download in Purview portal)."
    }
    catch { Write-Warning "Could not start export for ${searchName}: $_" }
  }

  Write-Host "KQL for $searchName saved to: $kqlFile"
}

# ---------- Summary ----------
Write-Host "`n--- Summary ---"
$results | Select-Object Name, Status, Items, Size, CreatedBy, CreatedTime | Format-Table -AutoSize
Write-Host "`nKQLs saved to: $kqlOutDir"
Write-Host "Tip: run with -KickOffExport to automatically launch export if needed."

