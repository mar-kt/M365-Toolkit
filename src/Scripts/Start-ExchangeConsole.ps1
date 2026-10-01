<#
.SYNOPSIS
    Interactive Command Center for M365 Toolkit.
.DESCRIPTION
    Provides a simple text-based menu to access reports, search, identity and backup tools.
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# Initialize default client name if not set
if (-not $global:M365ToolkitClientName) {
    $global:M365ToolkitClientName = "General"
}

function Show-Menu {
    Clear-Host
    $activeClient = if ($global:M365ToolkitClientName) { $global:M365ToolkitClientName } else { "General" }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "         M365 ADMIN TOOLKIT             " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " [Active Client: $activeClient]" -ForegroundColor Magenta
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host " 1. Mailbox Size & Quotas Report (Excel)"
    Write-Host " 2. Search & Export Archives (Purview KQL)"
    Write-Host " 3. Recycle Account / Offboard Identity"
    Write-Host " 4. Audit Email Forwarding Rules (Security)"
    Write-Host " 5. Find Stale / Inactive Mailboxes (>90d)"
    Write-Host " 6. Audit Mailbox Permissions (FullAccess/SendAs)"
    Write-Host " 7. Track Email Delivery (MessageTrace)"
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host " 8. Backup Dashboard (Archive Health)"
    Write-Host " 9. Backup Indexer (SQLite)"
    Write-Host "10. Search Backups (Offline Search)"
    Write-Host "11. Health Check (Environment Verification)"
    Write-Host "12. License Report (Microsoft Graph)"
    Write-Host "13. Modern MFA Status Report (Microsoft Graph)"
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host " C. Change Client Profile"
    Write-Host " D. Disconnect Sessions (Clean Cache)"
    Write-Host " Q. Quit"
    Write-Host "========================================" -ForegroundColor Cyan
}

do {
    Show-Menu
    $choice = Read-Host "Select an option"

    switch ($choice) {
        '1' {
            Write-Host "`nLaunching Mailbox Size Report..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MailboxSizeReport.ps1"
            
            $incArchive = Read-Host "Include Online Archive mailboxes? (Y/N) [Default: N]"
            $params = @{}
            if ($incArchive -eq 'Y' -or $incArchive -eq 'y') { $params['archive'] = $true }

            & $scriptPath @params
            Pause
        }
        '2' {
            Write-Host "`nLaunching Online Archive Search & Export..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Start-ArchiveSearch.ps1"
            & $scriptPath
            Pause
        }
        '3' {
            Write-Host "`nLaunching Identity Update Tool..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Update-UserIdentity.ps1"
            & $scriptPath
            Pause
        }
        '4' {
            Write-Host "`nLaunching Forwarding Rules Audit..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-ForwardingReport.ps1"
            & $scriptPath
            Pause
        }
        '5' {
            Write-Host "`nLaunching Inactive Mailbox Scan..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-StaleMailboxes.ps1"
            
            $days = Read-Host "Inactive days threshold [Default: 90]"
            if (-not $days) { $days = 90 }
            & $scriptPath -Days $days
            Pause
        }
        '6' {
            Write-Host "`nLaunching Permission Audit..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MailboxPermissionReport.ps1"
            & $scriptPath
            Pause
        }
        '7' {
            Write-Host "`nLaunching Email Delivery Tracker..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Search-DeliveryStatus.ps1"
            
            $s = Read-Host "Sender Address"
            $r = Read-Host "Recipient Address"
            if ($s -and $r) {
                & $scriptPath -Sender $s -Recipient $r
            }
            else {
                Write-Warning "Both Sender and Recipient addresses are required."
            }
            Pause
        }
        '8' {
            Write-Host "`nLoading Backup Dashboard..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-BackupReport.ps1"
            & $scriptPath
            Pause
        }
        '9' {
            Write-Host "`nLaunching Backup Indexer..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Index-Backups.ps1"
            
            $root = Read-Host "Path to Backup Root directory (e.g., C:\Backups or /mnt/Backups)"
            if ($root) { & $scriptPath -BackupRoot $root }
            Pause
        }
        '10' {
            Write-Host "`nLaunching Offline Backup Search..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Search-Backups.ps1"
            
            $root = Read-Host "Path to Backup Root directory"
            if ($root) {
                $subj = Read-Host "Subject Keyword (Optional)"
                $snd = Read-Host "Sender Address (Optional)"
                & $scriptPath -BackupRoot $root -Subject $subj -From $snd
            }
            Pause
        }
        '11' {
            Write-Host "`nRunning Environment Health Check..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Test-HealthCheck.ps1"
            & $scriptPath
            Pause
        }
        '12' {
            Write-Host "`nGenerating License Report (Microsoft Graph)..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-LicenseReport.ps1"
            & $scriptPath
            Pause
        }
        '13' {
            Write-Host "`nGenerating Modern MFA Status Report (Microsoft Graph)..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MFAStatusReport.ps1"
            & $scriptPath
            Pause
        }
        'C' -or 'c' {
            $newClient = Read-Host "Enter new Client Profile identifier [Current: $global:M365ToolkitClientName]"
            if ($newClient -and $newClient.Trim() -ne "") {
                $global:M365ToolkitClientName = $newClient.Trim()
                Write-Host "Active client set to: $global:M365ToolkitClientName" -ForegroundColor Green
            }
            Start-Sleep -Seconds 1
        }
        'D' -or 'd' {
            Disconnect-M365
            Pause
        }
        'Q' -or 'q' {
            Write-Host "`nGoodbye!" -ForegroundColor Green
            return
        }
        Default {
            Write-Warning "Invalid option."
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
