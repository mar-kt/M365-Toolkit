<#
.SYNOPSIS
    Audits Legacy Per-User MFA status (Enabled/Enforced/Disabled).
.DESCRIPTION
    Requires the 'MSOnline' module.
    Checks the 'StrongAuthenticationRequirements' property on MsolUser objects.
    Note: This does NOT detect Conditional Access Policies (Modern MFA).
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# --- Dependency Check ---
if (-not (Get-Module -ListAvailable -Name MSOnline)) {
    Write-Warning "This script requires the 'MSOnline' module."
    $install = Read-Host "Do you want to install it now? (Y/N)"
    if ($install -eq 'Y') {
        Install-Module MSOnline -Scope CurrentUser -Force
    }
    else {
        Write-Error "MSOnline module is missing. Exiting."
        exit
    }
}

# --- Connection ---
try {
    Write-Host "Connecting to Azure AD (MSOnline)..." -ForegroundColor Cyan
    Connect-MsolService -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to MSOnline: $_"
    exit
}

Write-Host "Auditing MFA Status..." -ForegroundColor Cyan

$users = Get-MsolUser -All
$results = @()

$total = $users.Count
$i = 0

foreach ($u in $users) {
    $i++
    Write-Progress -Activity "Auditing MFA" -Status "$($u.DisplayName)" -PercentComplete (($i / $total) * 100)
    
    $mfaStatus = "Disabled"
    if ($u.StrongAuthenticationRequirements) {
        $state = $u.StrongAuthenticationRequirements.State
        if ($state) { $mfaStatus = $state }
    }
    
    # Also check if they have registered methods (Phone/App)
    # The 'StrongAuthenticationMethods' property contains this.
    $hasMethods = if ($u.StrongAuthenticationMethods.Count -gt 0) { $true } else { $false }
    
    $results += [PSCustomObject]@{
        "User"       = $u.DisplayName
        "UPN"        = $u.UserPrincipalName
        "MFA Status" = $mfaStatus
        "HasMethods" = $hasMethods
        "IsLicensed" = $u.IsLicensed
    }
}

# --- Export ---
if ($results.Count -gt 0) {
    Write-Host "Found $($results.Count) users." -ForegroundColor Green
    Export-AdminReport -InputObject $results -ReportName "MFAStatusReport" -AutoOpen
}
else {
    Write-Warning "No users found?"
}
Write-Host "Done."
