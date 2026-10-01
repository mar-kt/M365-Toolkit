<#
.SYNOPSIS
    Interactive Command Center for Exchange Admin Tools.
.DESCRIPTION
    Provides a simple text-based menu to access reports, search, and user management tools.
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# Ensure Connection Once
Write-Host "Initializing Exchange Console..." -ForegroundColor Cyan
Connect-Exchange

function Show-Menu {
    Clear-Host
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host "   EXCHANGE ADMIN CONSOLE   " -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host "1. Get Mailbox Size Report (Excel)"
    Write-Host "2. Search & Export Archives"
    Write-Host "3. Rename User / Offboard Identity"
    Write-Host "4. Audit Forwarding Rules (Security)"
    Write-Host "5. Find Stale/Unused Mailboxes (Cost)"
    Write-Host "6. Audit Mailbox Permissions (Privacy)"
    Write-Host "7. Track Email Delivery (Support)"
    Write-Host "----------------------------"
    Write-Host "8. Backup Dashboard (Report)"
    Write-Host "9. Backup Indexer (Maintenance)"
    Write-Host "10. Search Backups (Tool)"
    Write-Host "11. Run Health Check (Maintenance)"
    Write-Host "12. License Report (Cost)"
    Write-Host "13. MFA Status Report (Security)"
    Write-Host "Q. Quit"
    Write-Host "============================" -ForegroundColor Cyan
}

do {
    Show-Menu
    $choice = Read-Host "Select an option"

    switch ($choice) {
        '1' {
            Write-Host "Launching Mailbox Report..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MailboxSizeReport.ps1"
            
            # Interactive prompt for Admin UPN if needed by the script, 
            # but usually the report script asks for it via parameter or connects automatically.
            # Our modified report script uses Connect-Exchange, so it should be fine.
            # But the param block requires 'adminUPN'. We should ask for it or let the script fail?
            # Actually, Get-MailboxSizeReport.ps1 has [Parameter(Mandatory=$true)] $adminUPN.
            # We can prompt here to be nice.
            
            $u = Read-Host "Enter Admin UPN (or press Enter if already connected)"
            $incArchive = Read-Host "Include Archive Mailboxes? (Y/N) [Default: N]"
            
            $params = @{}
            if ($u) { $params['adminUPN'] = $u }
            if ($incArchive -eq 'Y') { $params['archive'] = $true }

            & $scriptPath @params
            # Executed via splatting above
            
            Pause
        }
        '2' {
            Write-Host "Launching Archive Search..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Start-ArchiveSearch.ps1"
            
            # Start-ArchiveSearch also has mandatory params.
            # Let's just run it, powershell will prompt for mandatory params automatically!
            & $scriptPath
            
            Pause
        }
        '3' {
            Write-Host "Launching User Update Tool..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Update-UserIdentity.ps1"
            
            # Update-UserIdentity has Mandatory $Identity
            # PowerShell will prompt.
            & $scriptPath
            
            Pause
        }
        '4' {
            Write-Host "Launching Forwarding Audit..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-ForwardingReport.ps1"
            & $scriptPath
            Pause
        }
        '5' {
            Write-Host "Launching Stale Mailbox Scan..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-StaleMailboxes.ps1"
            
            $days = Read-Host "Days Inactive Threshold [Default: 90]"
            if (-not $days) { $days = 90 }
            & $scriptPath -Days $days
            
            Pause
        }
        '6' {
            Write-Host "Launching Permission Audit..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MailboxPermissionReport.ps1"
            & $scriptPath
            Pause
        }
        '7' {
            Write-Host "Launching Email Tracker..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Search-DeliveryStatus.ps1"
            
            $s = Read-Host "Sender Address"
            $r = Read-Host "Recipient Address"
            if ($s -and $r) {
                & $scriptPath -Sender $s -Recipient $r
            }
            else {
                Write-Warning "Both Sender and Recipient are required."
            }
            
            Pause
        }
        '8' {
            Write-Host "Launching Backup Dashboard..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-BackupReport.ps1"
            & $scriptPath
            Pause
        }
        '9' {
            Write-Host "Launching Backup Indexer..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Index-Backups.ps1"
            
            $root = Read-Host "Path to Backup Root (e.g. /mnt/Backups)"
            if ($root) { & $scriptPath -BackupRoot $root }
            Pause
        }
        '10' {
            Write-Host "Launching Backup Search..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Search-Backups.ps1"
            
            $root = Read-Host "Path to Backup Root"
            if ($root) {
                $subj = Read-Host "Subject Keyword (Optional)"
                $snd = Read-Host "Sender (Optional)"
                
                & $scriptPath -BackupRoot $root -Subject $subj -From $snd
            }
            Pause
        }
        '11' {
            Write-Host "Launching Health Check..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Test-HealthCheck.ps1"
            & $scriptPath
            Pause
        }
        '12' {
            Write-Host "Launching License Report..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-LicenseReport.ps1"
            & $scriptPath
            Pause
        }
        '13' {
            Write-Host "Launching MFA Report..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MFAStatusReport.ps1"
            & $scriptPath
            Pause
        }
        'Q' {
            Write-Host "Goodbye!" -ForegroundColor Green
            return
        }
        Default {
            Write-Warning "Invalid selection."
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
