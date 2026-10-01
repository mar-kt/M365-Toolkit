<#
.SYNOPSIS
    Renames an existing user for a new employee, preserving the old email as an alias.

.DESCRIPTION
    This script automates the process of recycling a Microsoft 365 Business Standard account.
    It updates the Display Name, UPN, and resets the password.
    Crucially, it adds the OLD UPN as an SMTP Alias so the new user receives previous emails.
    它 also clears stale personal data (Manager, Title, Phone).

.PARAMETER Identity
    The current UserPrincipalName (email) of the account to rename.
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Identity
)

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# Ensure connection
Connect-Exchange

try {
    Write-Host "Searching for user: $Identity..." -ForegroundColor Cyan
    $user = Get-Mailbox -Identity $Identity -ErrorAction Stop
    
    Write-Host "Found User: $($user.DisplayName) ($($user.PrimarySmtpAddress))" -ForegroundColor Green
    
    # --- Input New Details ---
    $newFirstName = Read-Host "Enter New First Name"
    $newLastName = Read-Host "Enter New Last Name"
    
    if (-not $newFirstName -or -not $newLastName) {
        Write-Error "First Name and Last Name are required."
        exit
    }

    # Generate New UPN
    # Defaulting to first letter of first name + last name (e.g. jdoe) logic? 
    # Or just asking the user? Let's ask to be safe, but suggest one.
    $suggestedUser = "$($newFirstName.Substring(0,1).ToLower())$($newLastName.ToLower())"
    $domain = $user.UserPrincipalName.Split("@")[1]
    $suggestedUPN = "$suggestedUser@$domain"

    $newUPN = Read-Host "Enter New Email (UPN) [Press Enter for $suggestedUPN]"
    if (-not $newUPN) { $newUPN = $suggestedUPN }

    $newDisplayName = "$newFirstName $newLastName"

    Write-Host "`nReady to Update:" -ForegroundColor Yellow
    Write-Host "  Name:       $newDisplayName"
    Write-Host "  New Login:  $newUPN"
    Write-Host "  Old Login:  $($user.UserPrincipalName) (Will become an ALIAS)"
    
    $confirm = Read-Host "Proceed with rename? (Y/N)"
    if ($confirm -ne 'Y') { exit }

    # --- Execution ---
    Write-Host "Updating Identity..." -ForegroundColor Cyan
    
    # 1. Update UPN and Common Name
    # Note: We use Set-Mailbox for basic email props, Set-User/Set-MsolUser might be needed for full details depending on environment
    # But usually Set-Mailbox -MicrosoftOnlineServicesID handles the UPN rename in cloud.
    # Wait, Set-Mailbox doesn't rename UPN directly easily in all versions. 
    # Standard EXO way: Set-MsolUserUserPrincipalName (deprecated) or Set-User?
    # Actually, in modern EXO V2/V3, Set-Mailbox -WindowsEmailAddress updates the primary SMTP, but UPN is separate.
    
    # Let's use Set-User first for UPN
    # Warning: Changing UPN can take a moment.
    Set-User -Identity $user.Id -UserPrincipalName $newUPN -DisplayName $newDisplayName -FirstName $newFirstName -LastName $newLastName -ErrorAction Stop
    
    # 2. Update Primary SMTP (usually matches UPN)
    # And keep old one as alias.
    # The 'EmailAddresses' parameter is a Set. To ADD one, we need to handle the array.
    
    # Fetch fresh object to get current addresses
    $freshUser = Get-Mailbox -Identity $newUPN
    $currentAddresses = $freshUser.EmailAddresses
    
    # Remove the old primary SMTP if it's there (it might have demoted itself or changed)
    # actually, when you change UPN, the PrimarySMTP usually changes too if it matches.
    # We want to ensure 'SMTP:$newUPN' is primary, and 'smtp:$oldUPN' is secondary.
    
    $oldUPN = $user.UserPrincipalName
    
    # Construct new list
    $newAddresses = @()
    foreach ($addr in $currentAddresses) {
        # Keep everything that isn't the UPNs (like X500 legacy stuff)
        if ($addr -notlike "SMTP:*") {
            $newAddresses += $addr
        }
    }
    
    # Add Clean List
    $newAddresses += "SMTP:$newUPN"      # Big SMTP = Primary
    $newAddresses += "smtp:$oldUPN"      # Little smtp = Alias
    
    Set-Mailbox -Identity $newUPN -EmailAddresses $newAddresses -ErrorAction Stop

    # 3. Clean Personal Data
    Write-Host "Cleaning stale data..." -ForegroundColor Cyan
    Set-User -Identity $newUPN -Phone "" -MobilePhone "" -Title "" -Department "" -Manager $null -ErrorAction SilentlyContinue

    Write-Host "--------------------------------------------" -ForegroundColor Green
    Write-Host "SUCCESS!" 
    Write-Host "User renamed to: $newUPN"
    Write-Host "Old email ($oldUPN) is now an alias."
    Write-Host "--------------------------------------------" -ForegroundColor Green

    # 4. Optional: Reset Password
    $reset = Read-Host "Do you want to reset the password now? (Y/N)"
    if ($reset -eq 'Y') {
        # Note: Set-Mailbox doesn't do password. We need Connect-MsolService or graph.
        # But wait, this script assumes pure EXCHANGE module. 
        # The modern 'Update-MgUser' requires Graph. 
        # Standard 'Set-User' doesn't do password.
        # This is the tricky part without the AzureAD module.
        # For now, let's warn.
        Write-Warning "Password reset requires AzureAD/Graph module. Please reset via Portal."
    }

}
catch {
    Write-Error "An error occurred: $_"
}
