<#
.SYNOPSIS
    Indexes backup contents into a portable SQLite database.
.DESCRIPTION
    Scans for backup Zip files, extracts metadata CSVs, and imports them into
    'backups.db' located at the BackupRoot.
.PARAMETER BackupRoot
    The root path of the backups.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$BackupRoot
)

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# Cross-platform check for sqlite3
try {
    if ($IsWindows) {
        # Check if sqlite3.exe is in path
        $null = Get-Command sqlite3 -ErrorAction Stop
    }
    else {
        $null = Get-Command sqlite3 -ErrorAction Stop
    }
}
catch {
    Write-Error "CRITICAL: 'sqlite3' command line tool not found. Please install it."
    # Windows: choco install sqlite
    # Linux: apt install sqlite3 / pacman -S sqlite
    exit 1
}

# Ensure .NET Zip support
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $BackupRoot)) {
    Write-Error "Backup root not found."
    exit 1
}

$dbPath = Join-Path $BackupRoot "backups.db"
Write-Host "Using Database: $dbPath" -ForegroundColor Cyan

# Initialize DB schema
$initSql = @"
CREATE TABLE IF NOT EXISTS Backups (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Filename TEXT UNIQUE,
    User TEXT,
    DateProcessed DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS Items (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    BackupId INTEGER,
    Subject TEXT,
    Sender TEXT,
    Recipient TEXT,
    SentTime TEXT,
    Size INTEGER,
    FOREIGN KEY(BackupId) REFERENCES Backups(Id)
);
"@
$initFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $initFile -Value $initSql
& sqlite3 $dbPath ".read '$initFile'"
Remove-Item $initFile

# Find Zips
Write-Host "Scanning for *.zip files..." -ForegroundColor Gray
$zips = Get-ChildItem -Path $BackupRoot -Recurse -Filter "*.zip"
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "BackupIndexer_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    foreach ($zip in $zips) {
        $relPath = $zip.FullName.Substring($BackupRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
        
        # Check if indexed
        $count = & sqlite3 $dbPath "SELECT Count(*) FROM Backups WHERE Filename = '$relPath';"
        if ($count -gt 0) {
            Write-Verbose "Skipping $relPath (Already Indexed)"
            continue
        }

        Write-Host "Indexing: $relPath" -ForegroundColor Yellow
        
        # 1. Register Backup
        # Extract User from path (heuristic: parent folder name)
        $user = $zip.Directory.Name
        & sqlite3 $dbPath "INSERT INTO Backups (Filename, User) VALUES ('$relPath', '$user');"
        # Fix: separate sqlite3 processes don't share session, so last_insert_rowid() is lost.
        # We must query by unique Filename to get the correctly persistent ID.
        $backupId = & sqlite3 $dbPath "SELECT Id FROM Backups WHERE Filename = '$relPath';"
        
        # 2. Extract Metadata CSVs
        try {
            $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
            $csvEntries = $zipArchive.Entries | Where-Object { $_.Name -like "Items_*.csv" }
            
            foreach ($csvEntry in $csvEntries) {
                Write-Host "  -> Processing $($csvEntry.Name)..." -ForegroundColor Gray
                $destCsv = Join-Path $tempDir "temp_$($csvEntry.Name)"
                
                # Extract
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($csvEntry, $destCsv, $true)
                
                # 3. Import CSV
                $csvData = Import-Csv $destCsv
                
                # Bulk Insert
                $batch = @()
                foreach ($row in $csvData) {
                    # Sanitize quotes
                    $sub = $row.Subject -replace "'", "''"
                    $snd = $row.Sender -replace "'", "''"
                    $rec = $row.Recipients -replace "'", "''"
                    $time = $row.Received
                    $size = $row.Size -replace "[^0-9]", ""
                    if (-not $size) { $size = 0 }
                    
                    $batch += "($backupId, '$sub', '$snd', '$rec', '$time', $size)"
                    
                    if ($batch.Count -ge 500) {
                        $values = $batch -join ","
                        & sqlite3 $dbPath "INSERT INTO Items (BackupId, Subject, Sender, Recipient, SentTime, Size) VALUES $values;"
                        $batch = @()
                    }
                }
                # Flush remaining
                if ($batch.Count -gt 0) {
                    $values = $batch -join ","
                    & sqlite3 $dbPath "INSERT INTO Items (BackupId, Subject, Sender, Recipient, SentTime, Size) VALUES $values;"
                }
                
                Write-Host "     Indexed $($csvData.Count) records." -ForegroundColor Green
                Remove-Item $destCsv -Force
            }
            
            if ($csvEntries.Count -eq 0) {
                Write-Warning "  -> No Items_*.csv found in zip."
            }
            $zipArchive.Dispose()
        }
        catch {
            Write-Warning "  -> Failed to read zip: $_"
        }
    }
}
finally {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Indexing Complete." -ForegroundColor Green
