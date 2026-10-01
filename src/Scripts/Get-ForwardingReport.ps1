<#
.SYNOPSIS
    Generates a security report of all email forwarding configurations.
.DESCRIPTION
    Scans all mailboxes for:
    1. SMTP Forwarding (Admin-configured)
    2. Inbox Rules (User-configured) that redirect or forward to external addresses.
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

Connect-Exchange

$results = @()
$mailboxes = Get-Mailbox -ResultSize Unlimited

$total = $mailboxes.Count
$i = 0

Write-Host "Scanning $total mailboxes for forwarding rules..." -ForegroundColor Cyan

foreach ($mbx in $mailboxes) {
    $i++
    Write-Progress -Activity "Auditing Mailboxes" -Status "$($mbx.DisplayName)" -PercentComplete (($i / $total) * 100)
    
    # 1. Check SMTP Forwarding
    if ($mbx.ForwardingAddress -or $mbx.ForwardingSmtpAddress) {
        $results += [PSCustomObject]@{
            "User"        = $mbx.DisplayName
            "UPN"         = $mbx.UserPrincipalName
            "Type"        = "SMTP Forwarding (Admin Set)"
            "Destination" = "$($mbx.ForwardingSmtpAddress) $($mbx.ForwardingAddress)"
            "Details"     = "DeliverToMailboxAndForward: $($mbx.DeliverToMailboxAndForward)"
        }
    }

    # 2. Check Inbox Rules (Client Side)
    # Note: Get-InboxRule can fail if permissions are missing or mailbox is weird, so we try/catch
    try {
        $rules = Get-InboxRule -Mailbox $mbx.UserPrincipalName -ErrorAction Stop
        foreach ($rule in $rules) {
            if ($rule.ForwardTo -or $rule.RedirectTo -or $rule.ForwardAsAttachmentTo) {
                # We want to flag EXTERNAL or suspicious ones. 
                # For now, let's report ALL forwards so the admin can decide.
                
                $dest = ""
                if ($rule.ForwardTo) { $dest += "FWD:$($rule.ForwardTo -join ';') " }
                if ($rule.RedirectTo) { $dest += "RED:$($rule.RedirectTo -join ';') " }
                if ($rule.ForwardAsAttachmentTo) { $dest += "ATT:$($rule.ForwardAsAttachmentTo -join ';') " }

                if ($dest) {
                    $results += [PSCustomObject]@{
                        "User"        = $mbx.DisplayName
                        "UPN"         = $mbx.UserPrincipalName
                        "Type"        = "Inbox Rule: $($rule.Name)"
                        "Destination" = $dest
                        "Details"     = "Enabled: $($rule.Enabled)"
                    }
                }
            }
        }
    }
    catch {
        # Squelch errors for system mailboxes or no-access
        # Write-Verbose "Could not read rules for $($mbx.UserPrincipalName): $_"
    }
}

# --- Export ---
if ($results.Count -eq 0) {
    Write-Host "No forwarding found! (Clean Scan)" -ForegroundColor Green
}
else {
    Write-Host "Found $($results.Count) suspicious entries." -ForegroundColor Red
    Export-AdminReport -InputObject $results -ReportName "ForwardingReport" -AutoOpen
}
Write-Host "Done."
