<#
.SYNOPSIS
    Quick summary report of user mailbox and archive sizes.
.DESCRIPTION
    Retrieves primary and archive mailbox statistics for active user accounts.
#>

# ----------------- MODULE AUTO-LOADING -----------------
. $PSScriptRoot/_Bootstrap.ps1
# -------------------------------------------------------

# Connect to Exchange Online
Connect-Exchange

Write-Host "Retrieving mailbox statistics..." -ForegroundColor Cyan

# Query all user mailboxes
$mailboxes = Get-Mailbox -ResultSize Unlimited | Where-Object { $_.RecipientTypeDetails -eq "UserMailbox" }

$results = @()

foreach ($mailbox in $mailboxes) {
    Write-Host "Processing: $($mailbox.DisplayName)..." -ForegroundColor Yellow
    
    # Query primary mailbox stats
    $stats = Get-MailboxStatistics -Identity $mailbox.UserPrincipalName -ErrorAction SilentlyContinue
    
    # Query archive mailbox stats if enabled
    $archiveStats = $null
    if ($mailbox.ArchiveStatus -eq "Active") {
        $archiveStats = Get-MailboxStatistics -Identity $mailbox.UserPrincipalName -Archive -ErrorAction SilentlyContinue
    }
    
    $result = [PSCustomObject]@{
        displayName        = $mailbox.DisplayName
        primaryEmail       = $mailbox.PrimarySmtpAddress
        primaryMailboxSize = if ($stats) { $stats.TotalItemSize.ToString() } else { "N/A" }
        archiveMailboxSize = if ($archiveStats) { $archiveStats.TotalItemSize.ToString() } else { "N/A" }
        totalItemCount     = if ($stats) { $stats.ItemCount } else { 0 }
    }
    
    $results += $result
}

# Export report
Export-AdminReport -InputObject $results -ReportName "SimpleMailboxStats" -AutoOpen
Write-Host "Done." -ForegroundColor Green
