<#
.SYNOPSIS
    Generates a report of Microsoft 365 Licenses assigned to users.
.DESCRIPTION
    Requires the 'MSOnline' module.
    Lists every user, whether they are licensed, and which specific license SKUs (e.g. ENTERPRISEPACK) are assigned.
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
    # MSOnline uses Connect-MsolService
    Write-Host "Connecting to Azure AD (MSOnline)..." -ForegroundColor Cyan
    Connect-MsolService -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to MSOnline: $_"
    exit
}

Write-Host "Retrieving User Licenses..." -ForegroundColor Cyan

$users = Get-MsolUser -All
$results = @()

$total = $users.Count
$i = 0

foreach ($u in $users) {
    $i++
    Write-Progress -Activity "Auditing Licenses" -Status "$($u.DisplayName)" -PercentComplete (($i / $total) * 100)
    
    $licenseNames = if ($u.Licenses) { ($u.Licenses.AccountSkuId -join ", ") } else { "None" }
    
    $results += [PSCustomObject]@{
        "User"          = $u.DisplayName
        "UPN"           = $u.UserPrincipalName
        "IsLicensed"    = $u.IsLicensed
        "Licenses"      = $licenseNames
        "Department"    = $u.Department
        "UsageLocation" = $u.UsageLocation
    }
}

# --- Export ---
if ($results.Count -gt 0) {
    Export-AdminReport -InputObject $results -ReportName "LicenseReport" -AutoOpen
}
else {
    Write-Warning "No users found?"
}
Write-Host "Done."
