<#
.SYNOPSIS
    Finds mailboxes that haven't been accessed in X days.
.DESCRIPTION
    Helps identify potential license savings by finding inactive users.
    Default threshold is 90 days.
#>

param(
    [int]$Days = 90
)

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

Connect-Exchange

$thresholdDate = (Get-Date).AddDays(-$Days)
Write-Host "Searching for users inactive since: $thresholdDate ($Days days)" -ForegroundColor Yellow

$mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox
$staleUsers = @()

$total = $mailboxes.Count
$i = 0

foreach ($mbx in $mailboxes) {
    $i++
    Write-Progress -Activity "Checking Login Stats" -Status "$($mbx.DisplayName)" -PercentComplete (($i / $total) * 100)

    # Get stats
    try {
        $stats = Get-EXOMailboxStatistics -Identity $mbx.UserPrincipalName -Properties LastLogonTime, LastUserActionTime -ErrorAction Stop
        
        # Determine "Last Active"
        # LastLogonTime allows us to see when the mailbox was accessed.
        # Note: Background processes can sometimes update this, but it's the best indicator we have without AzureAD SignIn logs.
        $lastActive = $stats.LastLogonTime
        if (-not $lastActive) { $lastActive = $stats.LastUserActionTime }
        
        $isStale = $false
        $daysInactive = "Never Logged In"
        
        if ($lastActive) {
            if ($lastActive -lt $thresholdDate) {
                $isStale = $true
                $daysInactive = ((Get-Date) - $lastActive).Days
            }
        }
        else {
            # Never logged in? Definitely stale.
            $isStale = $true
        }

        if ($isStale) {
            $staleUsers += [PSCustomObject]@{
                "Display Name"  = $mbx.DisplayName
                "UPN"           = $mbx.UserPrincipalName
                "Last Active"   = $lastActive
                "Days Inactive" = $daysInactive
                "Status"        = "Inactive > $Days Days"
            }
        }
    }
    catch {
        Write-Warning "Could not get stats for $($mbx.UserPrincipalName)"
    }
}

# --- Export ---
if ($staleUsers.Count -eq 0) {
    Write-Host "No stale mailboxes found! Everyone is active." -ForegroundColor Green
}
else {
    Write-Host "Found $($staleUsers.Count) stale accounts." -ForegroundColor Red
    Export-AdminReport -InputObject $staleUsers -ReportName "StaleMailboxes" -AutoOpen
}
Write-Host "Done."
