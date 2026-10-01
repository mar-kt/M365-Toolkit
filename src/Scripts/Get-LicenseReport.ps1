<#
.SYNOPSIS
    Generates a Microsoft 365 user license assignment report.
.DESCRIPTION
    Powered by the modern 'Microsoft.Graph.Users' module.
    Maps internal SkuIds to readable commercial product names (e.g., ENTERPRISEPACK, O365_BUSINESS_PREMIUM).
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# --- Dependency Check: Microsoft.Graph.Users ---
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Warning "This script requires the 'Microsoft.Graph.Users' module."
    $install = Read-Host "Do you want to install it now for CurrentUser? (Y/N)"
    if ($install -eq 'Y' -or $install -eq 'y') {
        Install-Module Microsoft.Graph.Users -Scope CurrentUser -Force
    }
    else {
        Write-Error "Missing required module: Microsoft.Graph.Users. Aborting execution."
        exit
    }
}

# --- Connect to Microsoft Graph ---
Connect-M365Graph -Scopes @('User.Read.All', 'Organization.Read.All')

Write-Host "Querying tenant subscribed license SKUs..." -ForegroundColor Cyan

# 1. Retrieve subscribed SKUs to map SkuId to friendly part numbers
$skuDict = @{}
try {
    $subscribedSkus = Get-MgSubscribedSku -All -ErrorAction SilentlyContinue
    if ($subscribedSkus) {
        foreach ($s in $subscribedSkus) {
            $skuDict[$s.SkuId] = $s.SkuPartNumber
        }
    }
}
catch {
    Write-Verbose "Could not retrieve full subscribed SKU catalog: $_"
}

# 2. Retrieve users and assigned licenses
Write-Host "Retrieving users and assigned licenses..." -ForegroundColor Cyan

try {
    $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,Department,UsageLocation,AssignedLicenses -ErrorAction Stop
}
catch {
    Write-Error "Error querying users from Microsoft Graph: $_"
    exit
}

$results = @()
$total = $users.Count
$i = 0

Write-Host "Processing $total users..." -ForegroundColor Yellow

foreach ($u in $users) {
    $i++
    Write-Progress -Activity "Auditing Licenses" -Status "$($u.DisplayName)" -PercentComplete (($i / $total) * 100)

    $assignedNames = @()
    if ($u.AssignedLicenses) {
        foreach ($lic in $u.AssignedLicenses) {
            $skuName = if ($skuDict.ContainsKey($lic.SkuId)) { $skuDict[$lic.SkuId] } else { $lic.SkuId }
            $assignedNames += $skuName
        }
    }

    $isLicensed = ($assignedNames.Count -gt 0)

    $results += [PSCustomObject]@{
        "User"           = $u.DisplayName
        "UPN"            = $u.UserPrincipalName
        "AccountEnabled" = $u.AccountEnabled
        "IsLicensed"     = $isLicensed
        "LicenseCount"   = $assignedNames.Count
        "Licenses"       = if ($assignedNames) { ($assignedNames -join ", ") } else { "None" }
        "Department"     = $u.Department
        "UsageLocation"  = $u.UsageLocation
    }
}

# --- Export Report ---
if ($results.Count -gt 0) {
    Export-AdminReport -InputObject $results -ReportName "LicenseReport" -AutoOpen
}
else {
    Write-Warning "No users found in tenant."
}

Write-Host "Done." -ForegroundColor Green
