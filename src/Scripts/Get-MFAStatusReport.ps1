<#
.SYNOPSIS
    Audits user Multi-Factor Authentication (MFA) registration status and modern protection methods.
.DESCRIPTION
    Powered by the modern 'Microsoft.Graph.Identity.SignIns' module.
    Audits actual authentication methods registered by each user
    (Microsoft Authenticator, FIDO2, Phone, Windows Hello, etc.), fully compatible with Conditional Access.
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# --- Dependency Check: Microsoft.Graph.Identity.SignIns ---
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.SignIns)) {
    Write-Warning "This script requires the 'Microsoft.Graph.Identity.SignIns' module."
    $install = Read-Host "Do you want to install it now for CurrentUser? (Y/N)"
    if ($install -eq 'Y' -or $install -eq 'y') {
        Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser -Force
    }
    else {
        Write-Error "Missing required module: Microsoft.Graph.Identity.SignIns. Aborting execution."
        exit
    }
}

# --- Connect to Microsoft Graph ---
Connect-M365Graph -Scopes @('User.Read.All', 'UserAuthenticationMethod.Read.All')

Write-Host "Querying users for MFA status audit..." -ForegroundColor Cyan

try {
    $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses -ErrorAction Stop
}
catch {
    Write-Error "Error querying users from Microsoft Graph: $_"
    exit
}

$results = @()
$total = $users.Count
$i = 0

Write-Host "Auditing registered authentication methods across $total users..." -ForegroundColor Yellow

foreach ($u in $users) {
    $i++
    Write-Progress -Activity "Auditing MFA Methods" -Status "$($u.DisplayName)" -PercentComplete (($i / $total) * 100)

    $methodsList = @()
    $hasMfaMethod = $false

    try {
        $authMethods = Get-MgUserAuthenticationMethod -UserId $u.Id -ErrorAction Stop
        foreach ($m in $authMethods) {
            $type = $m.AdditionalProperties['@odata.type']
            switch ($type) {
                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                    $methodsList += "Microsoft Authenticator"
                    $hasMfaMethod = $true
                }
                "#microsoft.graph.phoneAuthenticationMethod" {
                    $methodsList += "Phone/SMS"
                    $hasMfaMethod = $true
                }
                "#microsoft.graph.fido2AuthenticationMethod" {
                    $methodsList += "FIDO2/SecurityKey"
                    $hasMfaMethod = $true
                }
                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                    $methodsList += "Windows Hello"
                    $hasMfaMethod = $true
                }
                "#microsoft.graph.softwareOathAuthenticationMethod" {
                    $methodsList += "Software Token (TOTP)"
                    $hasMfaMethod = $true
                }
                "#microsoft.graph.emailAuthenticationMethod" {
                    $methodsList += "Email"
                }
                "#microsoft.graph.passwordAuthenticationMethod" {
                    # Baseline primary password
                }
                Default {
                    if ($type) {
                        $cleanType = $type -replace '^#microsoft\.graph\.', '' -replace 'AuthenticationMethod$', ''
                        $methodsList += $cleanType
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose "Could not retrieve authentication methods for $($u.UserPrincipalName): $_"
    }

    $mfaStatus = if ($hasMfaMethod) { "MFA Configured" } else { "No MFA Methods" }

    $results += [PSCustomObject]@{
        "User"              = $u.DisplayName
        "UPN"               = $u.UserPrincipalName
        "AccountEnabled"    = $u.AccountEnabled
        "IsLicensed"        = ($u.AssignedLicenses.Count -gt 0)
        "MFA Status"        = $mfaStatus
        "HasMFA"            = $hasMfaMethod
        "MethodsCount"      = $methodsList.Count
        "RegisteredMethods" = if ($methodsList) { ($methodsList -join ", ") } else { "None" }
    }
}

# --- Export Report ---
if ($results.Count -gt 0) {
    Export-AdminReport -InputObject $results -ReportName "MFAStatusReport" -AutoOpen
}
else {
    Write-Warning "No user records retrieved."
}

Write-Host "Done." -ForegroundColor Green
