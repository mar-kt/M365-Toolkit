<#
.SYNOPSIS
    Audits who has access to mailboxes (FullAccess and SendAs).
.DESCRIPTION
    Scans mailboxes to identify non-standard permissions.
    Filters out the owner and system accounts to reduce noise.
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

Connect-Exchange

$results = @()
$mailboxes = Get-Mailbox -ResultSize Unlimited

$total = $mailboxes.Count
$i = 0

Write-Host "Scanning $total mailboxes for permissions..." -ForegroundColor Cyan

foreach ($mbx in $mailboxes) {
    $i++
    Write-Progress -Activity "Auditing Permissions" -Status "$($mbx.DisplayName)" -PercentComplete (($i / $total) * 100)

    # 1. Full Access
    try {
        $perms = Get-MailboxPermission -Identity $mbx.UserPrincipalName -ErrorAction Stop | Where-Object { 
            # Filter out "Self" and standard system SIDs/Users
            $_.User -notlike "NT AUTHORITY\*" -and 
            $_.User -notlike "S-1-5-*" -and
            $_.AccessRights -contains "FullAccess"
        }
        
        foreach ($p in $perms) {
            # Double check it's not the user themselves (sometimes shows up by name)
            if ($p.User -ne $mbx.DisplayName -and $p.User -ne $mbx.Name) {
                $results += [PSCustomObject]@{
                    "Mailbox"        = $mbx.DisplayName
                    "MailboxUPN"     = $mbx.UserPrincipalName
                    "Type"           = "Mailbox (FullAccess)"
                    "UserWithAccess" = $p.User
                    "IsInherited"    = $p.IsInherited
                }
            }
        }
    }
    catch {}

    # 2. Send As
    try {
        $sendAs = Get-RecipientPermission -Identity $mbx.UserPrincipalName -ErrorAction Stop | Where-Object {
            $_.Trustee -notlike "NT AUTHORITY\*" -and
            $_.Trustee -notlike "S-1-5-*"
        }
        foreach ($s in $sendAs) {
            if ($s.Trustee -ne $mbx.DisplayName -and $s.Trustee -ne $mbx.Name -and $s.Trustee -ne "Self") {
                $results += [PSCustomObject]@{
                    "Mailbox"        = $mbx.DisplayName
                    "MailboxUPN"     = $mbx.UserPrincipalName
                    "Type"           = "Recipient (SendAs)"
                    "UserWithAccess" = $s.Trustee
                    "IsInherited"    = $false
                }
            }
        }
    }
    catch {}
}

# --- Export ---
# --- Export ---
if ($results.Count -eq 0) {
    Write-Host "No custom permissions found." -ForegroundColor Green
}
else {
    Write-Host "Found $($results.Count) permission entries." -ForegroundColor Red
    Export-AdminReport -InputObject $results -ReportName "PermissionReport" -AutoOpen
}
Write-Host "Done."
