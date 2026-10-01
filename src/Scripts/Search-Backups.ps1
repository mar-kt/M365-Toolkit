<#
.SYNOPSIS
    Searches the local backup index for specific emails.
.DESCRIPTION
    Queries the 'backups.db' SQLite database to find which Zip file contains
    the requested message.
.PARAMETER Subject
    Subject line to search for (partial match).
.PARAMETER Sender
    Sender address to search for.
.PARAMETER Recipient
    Recipient address to search for.
.PARAMETER BackupRoot
    The root path of the backups.
#>

param(
    [string]$Subject,
    [string]$From,
    [string]$Recipient,
    
    [Parameter(Mandatory = $true)]
    [string]$BackupRoot
)

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# Cross-platform check for sqlite3
try {
    if ($IsWindows) { $null = Get-Command sqlite3 -ErrorAction Stop } 
    else { $null = Get-Command sqlite3 -ErrorAction Stop }
}
catch {
    Write-Error "CRITICAL: 'sqlite3' command line tool not found."
    exit 1
}

if (-not (Test-Path $BackupRoot)) {
    Write-Error "Backup root not found."
    exit 1
}

$dbPath = Join-Path $BackupRoot "backups.db"
if (-not (Test-Path $dbPath)) {
    Write-Error "Index not found at $dbPath. Run Index-Backups.ps1 first."
    exit 1
}

# Construct SQL
$clauses = @()
if ($Subject) { $clauses += "Subject LIKE '%$Subject%'" }
if ($From) { $clauses += "Sender LIKE '%$From%'" }
if ($Recipient) { $clauses += "Recipient LIKE '%$Recipient%'" }

if ($clauses.Count -eq 0) {
    Write-Warning "No search criteria provided. Listing top 10 recent items."
    $where = "1=1 ORDER BY I.Id DESC LIMIT 10"
}
else {
    $where = ($clauses -join " AND ") + " ORDER BY SentTime DESC LIMIT 100"
}

$query = "SELECT B.User, B.Filename, I.Subject, I.Sender, I.SentTime, I.Size FROM Items I JOIN Backups B ON I.BackupId = B.Id WHERE $where;"

Write-Host "Searching..." -ForegroundColor Cyan

# Run query and parse output
# sqlite3 default output is pipe-delimited or list? Default is pipe.
# We can use -header -line or -csv to make parsing easier. -csv is best.

$results = & sqlite3 -header -csv $dbPath $query | ConvertFrom-Csv

if ($results) {
    $results | Format-Table -AutoSize
    Write-Host "Found $($results.Count) matches." -ForegroundColor Green
}
else {
    Write-Warning "No matches found."
}
