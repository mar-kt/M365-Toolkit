<#
.SYNOPSIS
  Archive-only Compliance Search (Exchange Online / Purview) - cross-platform (Linux/macOS/Windows, PowerShell 7+)
.DESCRIPTION
  Retrieves Online Archive folders for a mailbox, converts FolderId (EWS Base64) to valid IndexId HEX for KQL,
  builds 'folderid:HEX OR ...' queries, partitions them if necessary, creates and executes Compliance Search(es)
  that return exclusively the archive content. Optional export.
  
  [ENHANCED]: Unique timestamped search names, Purview backend propagation delay, 
  automatic action cleanup, query complexity limits, and retry logic.
.NOTES
  Requirements: PowerShell 7+ (pwsh), ExchangeOnlineManagement module, Exchange and eDiscovery/Compliance permissions.
#>

param(
  [Parameter(Mandatory = $true, HelpMessage = "User Principal Name (e.g. user@domain.com)")]
  [string]$UserUpn,

  [string]$BaseSearchName = $null,         # If null, generated from $UserUpn + timestamp

  [int]$MaxFoldersPerQuery = 60,           # Max folders per KQL query (prevents KQL complexity/OR limit errors)

  [int]$MaxQueryLength = 4000,             # Safe limit for KQL length in Purview

  [bool]$ExcludeDumpster = $true,          # Exclude Recoverable Items from Archive

  [bool]$KickOffExport = $false,           # Start export after each search completes

  [bool]$ExportIncludeUnsearchable = $true # Include Unsearchable Items in export
)

# ----------------- MODULE AUTO-LOADING -----------------
. $PSScriptRoot/_Bootstrap.ps1
# -------------------------------------------------------

# ---------- Utilities ----------
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

# ---------- Run Timestamp & Search Name Generation ----------
$runTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (-not $BaseSearchName) {
  $sanitized = ($UserUpn -replace '[^a-zA-Z0-9]', '_').Trim('_')
  # Unique timestamp prevents collision with prior searches or orphaned export actions
  $BaseSearchName = "ArchiveOnly_${sanitized}_${runTimestamp}"
}

# ---------- Connections: EXO and Purview ----------
# Connect to Exchange Online
Connect-Exchange

# Connect to Purview / Security & Compliance
if (-not (Test-HasCommand "Get-ComplianceSearch")) {
  Write-Host "Connecting to Security & Compliance / Purview (Connect-IPPSSession)..." -ForegroundColor Cyan
  try {
    Connect-IPPSSession -ErrorAction Stop
  }
  catch {
    throw "Failed to load Purview cmdlets (Get/New/Start-ComplianceSearch). Ensure your account has the 'eDiscovery Manager' role in Purview. Detail: $_"
  }
}
else {
  Write-Verbose "Compliance cmdlets already available."
}

# ---------- Mailbox and Archive Validation ----------
try {
  $mailbox = Get-Mailbox -Identity $UserUpn -ErrorAction Stop
}
catch {
  throw "Could not retrieve mailbox $UserUpn. Error: $_"
}

if (-not $mailbox.ArchiveStatus -or $mailbox.ArchiveStatus -eq "None") {
  throw "User $UserUpn does not have Online Archive enabled (ArchiveStatus: $($mailbox.ArchiveStatus))."
}

Write-Host "Validating archive for: $($mailbox.DisplayName) ($UserUpn)..." -ForegroundColor Cyan

# ---------- Archive Folders Extraction ----------
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
if (-not $folderIds -or $folderIds.Count -eq 0) {
  throw "No FolderIds found in Archive for $UserUpn (after filtering)."
}

Write-Host "Total folders in Archive: $($folderIds.Count)." -ForegroundColor Green

# ---------- Output Directory for KQL Files ----------
$toolkitRoot = Resolve-Path (Join-Path $PSScriptRoot "../..") -ErrorAction SilentlyContinue
$outputBase = if ($toolkitRoot) { Join-Path $toolkitRoot.Path "output" } else { $null }

if ($outputBase -and (Test-Path $outputBase)) {
  $clientDir = if ($global:M365ToolkitClientName) { $global:M365ToolkitClientName } else { "General" }
  $kqlOutDir = Join-Path $outputBase (Join-Path $clientDir "kql\$runTimestamp")
}
else {
  $tmp = [System.IO.Path]::GetTempPath(); if (-not $tmp) { $tmp = "/tmp" }
  $kqlOutDir = Join-Path $tmp ("ArchiveOnlyKql_" + $runTimestamp)
}

New-Item -ItemType Directory -Path $kqlOutDir -Force | Out-Null
Write-Host "KQL queries will be saved to: $kqlOutDir" -ForegroundColor Cyan

# ---------- Partitioning by Length & Folder Count ----------
# Purview limits both KQL string length and number of Boolean OR operators
$chunks = New-Object System.Collections.Generic.List[object]
$current = New-Object System.Collections.Generic.List[string]

foreach ($id in $folderIds) {
  $testArr = @($current + $id)
  try { $test = Build-KqlFromArchiveFolders -EwsFolderIds $testArr } catch { $test = "" }
  
  if (($test.Length -gt $MaxQueryLength -or $current.Count -ge $MaxFoldersPerQuery) -and $current.Count -gt 0) {
    $chunks.Add($current.ToArray())
    $current = New-Object System.Collections.Generic.List[string]
  }
  $current.Add($id)
}
if ($current.Count -gt 0) {
  $chunks.Add($current.ToArray())
}

Write-Host "Query partitioned into $($chunks.Count) safe search block(s)." -ForegroundColor Yellow

# ---------- Create and Execute Compliance Searches ----------
$results = @()

for ($idx = 0; $idx -lt $chunks.Count; $idx++) {
  $part = $chunks[$idx]
  $kql = Build-KqlFromArchiveFolders -EwsFolderIds $part
  $searchName = if ($chunks.Count -gt 1) { "$BaseSearchName`_part$($idx+1)" } else { $BaseSearchName }

  # Save KQL for audit and manual inspection
  $kqlFile = Join-Path $kqlOutDir "$searchName.kql.txt"
  try {
    $kql | Out-File -FilePath $kqlFile -Encoding UTF8 -Force
    Write-Host "  -> KQL saved ($($part.Count) folders): $kqlFile" -ForegroundColor DarkGray
  }
  catch {
    Write-Warning "Could not write ${kqlFile}: $_"
  }

  # Clean existing search and associated actions if a custom BaseSearchName was passed
  try {
    $existing = Get-ComplianceSearch -Identity $searchName -ErrorAction SilentlyContinue
    if ($existing) {
      Write-Host "Found existing search '$searchName'. Cleaning associated actions first..." -ForegroundColor Yellow
      $actions = Get-ComplianceSearchAction | Where-Object { $_.SearchName -eq $searchName } -ErrorAction SilentlyContinue
      foreach ($act in $actions) {
        Write-Host "Removing associated action '$($act.Name)'..." -ForegroundColor DarkYellow
        Remove-ComplianceSearchAction -Identity $act.Name -Confirm:$false -ErrorAction SilentlyContinue
      }
      Start-Sleep -Seconds 3
      Write-Host "Removing previous search '$searchName'..." -ForegroundColor Yellow
      Remove-ComplianceSearch -Identity $searchName -Confirm:$false -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 5
    }
  }
  catch {
    Write-Warning "Warning cleaning existing search: $_"
  }

  # 1. Create Compliance Search
  try {
    Write-Host "Creating ComplianceSearch '$searchName' in Purview..." -ForegroundColor Cyan
    New-ComplianceSearch -Name $searchName -ExchangeLocation $UserUpn -ContentMatchQuery $kql -ErrorAction Stop | Out-Null
    Write-Host "Search created. Waiting 4 seconds for Purview backend propagation..." -ForegroundColor Gray
    Start-Sleep -Seconds 4
  }
  catch {
    throw "Error creating ComplianceSearch '$searchName': $_"
  }

  # 2. Start Compliance Search (with Retry logic for transient backend synchronization)
  $started = $false
  $startAttempts = 0
  $maxStartAttempts = 3

  while (-not $started -and $startAttempts -lt $maxStartAttempts) {
    $startAttempts++
    try {
      Write-Host "Starting ComplianceSearch '$searchName' (Attempt $startAttempts of $maxStartAttempts)..." -ForegroundColor Cyan
      Start-ComplianceSearch -Identity $searchName -ErrorAction Stop | Out-Null
      $started = $true
      Write-Host "Search successfully started." -ForegroundColor Green
    }
    catch {
      Write-Warning "Attempt $startAttempts to start search failed: $_"
      if ($startAttempts -lt $maxStartAttempts) {
        Write-Host "Waiting 5 seconds before retrying Start-ComplianceSearch..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
      }
      else {
        throw "Failed to start ComplianceSearch '$searchName' after $maxStartAttempts attempts. Detail: $_"
      }
    }
  }

  # 3. Polling until completion with Timeout
  $state = ""
  $startTime = Get-Date
  $timeoutSeconds = 3600 # 1 Hour Timeout

  Write-Host "Waiting for search results..." -ForegroundColor Cyan

  do {
    Start-Sleep -Seconds 5

    if ((Get-Date) -gt $startTime.AddSeconds($timeoutSeconds)) {
      throw "Timeout waiting for search '$searchName' to complete."
    }

    try {
      $info = Get-ComplianceSearch -Identity $searchName -ErrorAction Stop
      $state = $info.Status
      Write-Host "$searchName -> State: $state | Items: $($info.Items) | Size: $($info.Size)"
    }
    catch {
      Write-Host "$searchName -> State: (retrieving state...)"; $state = ""
    }
  } until ($state -in @("Completed", "PartiallySucceeded", "Failed"))

  $info = Get-ComplianceSearch -Identity $searchName
  $results += $info

  # 4. Optional Export
  if ($KickOffExport) {
    try {
      Write-Host "Starting direct export for $searchName..." -ForegroundColor Cyan
      $null = New-ComplianceSearchAction -SearchName $searchName -Export `
        -Format FxStream `
        -EnableDedupe:$true `
        -Scope Both `
        -IncludeUnsearchableItems:$ExportIncludeUnsearchable -ErrorAction Stop
      Write-Host "Export started for $searchName (available for download in Microsoft Purview Portal)." -ForegroundColor Green
    }
    catch {
      Write-Warning "Could not start export for ${searchName}: $_"
    }
  }
}

# ---------- Summary ----------
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "           SEARCH SUMMARY               " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
$results | Select-Object Name, Status, Items, Size, CreatedTime | Format-Table -AutoSize
Write-Host "KQL files saved to: $kqlOutDir" -ForegroundColor Cyan
Write-Host "Tip: Run with -KickOffExport:`$true to trigger export download packages automatically."
