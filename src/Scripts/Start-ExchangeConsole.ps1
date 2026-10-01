<#
.SYNOPSIS
    Interactive Command Center for M365 Toolkit.
.DESCRIPTION
    Provides a simple text-based menu to access reports, search, identity and backup tools.
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

function Get-DetectedTenant {
    # 1. Check Exchange Online active session via Get-ConnectionInformation
    try {
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $connections = Get-ConnectionInformation -ErrorAction SilentlyContinue
            if ($connections) {
                # Prefer active connected session
                $active = $connections | Where-Object { -not $_.State -or $_.State -eq 'Connected' } | Select-Object -First 1
                if (-not $active) { $active = $connections | Select-Object -First 1 }

                if ($active) {
                    if ($active.Organization -and $active.Organization.Trim() -ne "") {
                        return $active.Organization.Trim()
                    }
                    if ($active.UserPrincipalName -and $active.UserPrincipalName.Contains("@")) {
                        return ($active.UserPrincipalName -split '@')[-1].Trim()
                    }
                }
            }
        }
    }
    catch {}

    # 2. Check active Exchange cmdlets if already imported in session
    try {
        if (Get-Command Get-AcceptedDomain -ErrorAction SilentlyContinue) {
            $domain = (Get-AcceptedDomain -ErrorAction SilentlyContinue | Where-Object { $_.Default -or $_.IsDefault } | Select-Object -First 1).DomainName
            if ($domain) { return $domain }
        }
    }
    catch {}

    # 3. Check Microsoft Graph active session
    try {
        if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
            $mg = Get-MgContext -ErrorAction SilentlyContinue
            if ($mg -and $mg.Account -and $mg.Account.Contains("@")) {
                return ($mg.Account -split '@')[-1].Trim()
            }
        }
    }
    catch {}

    # 4. Fallback check for legacy Remote PowerShell sessions (Get-PSSession)
    try {
        $sess = Get-PSSession | Where-Object { $_.State -eq 'Opened' -and ($_.ConfigurationName -match 'Exchange' -or $_.Name -like '*Exchange*') } | Select-Object -First 1
        if ($sess -and $sess.ConnectionUri) {
            return $sess.ConnectionUri.Host
        }
    }
    catch {}

    return $null
}

function Get-ActiveOutputFolder {
    if ($global:M365ToolkitCustomOutputFolder) {
        return $global:M365ToolkitCustomOutputFolder
    }
    $detected = Get-DetectedTenant
    if ($detected) {
        return $detected
    }
    return "General"
}

function Show-Menu {
    try { Clear-Host } catch {}
    
    $tenant = Get-DetectedTenant
    $tenantDisplay = if ($tenant) { $tenant } else { "Disconnected" }
    $activeFolder = Get-ActiveOutputFolder
    $global:M365ToolkitClientName = $activeFolder
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "         M365 ADMIN TOOLKIT             " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " [Tenant: $tenantDisplay | Output Folder: $activeFolder]" -ForegroundColor Magenta
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
    Write-Host " C. Change Output Folder"
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
        'C' {
            $currentFolder = Get-ActiveOutputFolder
            $newFolder = Read-Host "Enter custom Output Folder name (leave empty to reset to auto-detect) [Current: $currentFolder]"
            if ($newFolder -and $newFolder.Trim() -ne "") {
                $global:M365ToolkitCustomOutputFolder = $newFolder.Trim()
                Write-Host "Output Folder set to: $global:M365ToolkitCustomOutputFolder" -ForegroundColor Green
            }
            else {
                $global:M365ToolkitCustomOutputFolder = $null
                Write-Host "Output Folder reset to auto-detect." -ForegroundColor Yellow
            }
            Start-Sleep -Seconds 1
        }
        'D' {
            Disconnect-M365
            Pause
        }
        'Q' {
            Write-Host "`nGoodbye!" -ForegroundColor Green
            return
        }
        Default {
            Write-Warning "Invalid option."
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
