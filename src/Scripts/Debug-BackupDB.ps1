param([string]$BackupRoot)

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

if (-not $BackupRoot) { $BackupRoot = Read-Host "Path to Backup Root" }
$db = Join-Path $BackupRoot "backups.db"
$sqlite = if ($IsWindows) { "sqlite3" } else { "sqlite3" }

Write-Host "--- DATA INTEGRITY CHECK ---" -ForegroundColor Cyan
Write-Host "DB: $db"
Write-Host "Size: $((Get-Item $db).Length / 1MB) MB"

$c1 = & $sqlite $db "SELECT Count(*) FROM Backups;"
Write-Host "Backups Count: $c1" -ForegroundColor Green

$c2 = & $sqlite $db "SELECT Count(*) FROM Items;"
Write-Host "Items Count:   $c2" -ForegroundColor Green

$c3 = & $sqlite $db "SELECT Count(*) FROM Items I LEFT JOIN Backups B ON I.BackupId = B.Id WHERE B.Id IS NULL;"
Write-Host "Orphan Items:  $c3" -ForegroundColor Red

if ($c2 -eq 0 -and $c1 -gt 0) {
    Write-Warning "Items table is empty but Backups exist. Did the Indexer fail to parse CSVs?"
}
