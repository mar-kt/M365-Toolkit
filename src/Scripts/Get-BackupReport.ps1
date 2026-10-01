<#
.SYNOPSIS
    Generates a visual dashboard of the local backup archive.
.DESCRIPTION
    Scans the backup directory structure (Year/User/Date) to report on:
    - Total size per user
    - Last backup date (Stale detection)
    - Total archive growth
.PARAMETER BackupRoot
    The root path of the backups. Defaults to the 'backups' folder relative to the script.
#>

param(
    [string]$BackupRoot = ""
)

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# Resolve Root
if (-not $BackupRoot) {
    # Try to detect if we are in src/Scripts and backups is in root
    $possibleRoot = Resolve-Path (Join-Path $PSScriptRoot "../../backups") -ErrorAction SilentlyContinue
    if ($possibleRoot) { $BackupRoot = $possibleRoot.Path }
    else {
        $BackupRoot = Read-Host "Enter path to Backup Root (e.g. /mnt/Drive/backups)"
    }
}

if (-not (Test-Path $BackupRoot)) {
    Write-Error "Backup root not found: $BackupRoot"
    exit
}

Write-Host "Scanning backups in: $BackupRoot" -ForegroundColor Cyan
$years = Get-ChildItem -Path $BackupRoot -Directory
$data = @()
$staleThreshold = (Get-Date).AddDays(-30)

foreach ($y in $years) {
    # Year folder
    $yearPath = $y.FullName
    $users = Get-ChildItem -Path $yearPath -Directory
    
    foreach ($u in $users) {
        # User folder (e.g. caguilera)
        $userPath = $u.FullName
        $backups = Get-ChildItem -Path $userPath -File -Filter "*.zip"
        
        if ($backups) {
            $latest = $backups | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $totalSize = ($backups | Measure-Object -Property Length -Sum).Sum
            
            $data += [PSCustomObject]@{
                "User"            = $u.Name
                "Year"            = $y.Name
                "Backup Count"    = $backups.Count
                "Total Size (MB)" = [math]::Round($totalSize / 1MB, 2)
                "Last Backup"     = $latest.LastWriteTime
                "Status"          = if ($latest.LastWriteTime -lt $staleThreshold) { "Stale (>30 days)" } else { "Healthy" }
                "Latest File"     = $latest.Name
            }
        }
        else {
            $data += [PSCustomObject]@{
                "User"            = $u.Name
                "Year"            = $y.Name
                "Backup Count"    = 0
                "Total Size (MB)" = 0
                "Last Backup"     = "NEVER"
                "Status"          = "CRITICAL (Empty)"
                "Latest File"     = ""
            }
        }
    }
}

# --- Export ---
if ($data.Count -gt 0) {
    Export-AdminReport -InputObject $data -ReportName "BackupDashboard" -AutoOpen
}
else {
    Write-Warning "No backups found."
}
Write-Host "Done."
