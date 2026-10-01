<#
.SYNOPSIS
    Audita el estado de registro de métodos MFA y protección moderna de los usuarios.
.DESCRIPTION
    Utiliza el modulo moderno 'Microsoft.Graph.Identity.SignIns'.
    Audita los métodos de autenticación registrados realmente por cada usuario
    (Microsoft Authenticator, FIDO2, Phone, Windows Hello, etc.), compatible con Conditional Access.
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# --- Dependencia: Microsoft.Graph.Identity.SignIns ---
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.SignIns)) {
    Write-Warning "Este script requiere el modulo 'Microsoft.Graph.Identity.SignIns'."
    $install = Read-Host "Desea instalarlo ahora para el usuario actual? (Y/N)"
    if ($install -eq 'Y') {
        Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser -Force
    }
    else {
        Write-Error "Falta el modulo Microsoft.Graph.Identity.SignIns. Abortando ejecucion."
        exit
    }
}

# --- Conexion con Microsoft Graph ---
Connect-M365Graph -Scopes @('User.Read.All', 'UserAuthenticationMethod.Read.All')

Write-Host "Consultando usuarios para auditoría de MFA..." -ForegroundColor Cyan

try {
    $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,AssignedLicenses -ErrorAction Stop
}
catch {
    Write-Error "Error al consultar usuarios desde Microsoft Graph: $_"
    exit
}

$results = @()
$total = $users.Count
$i = 0

Write-Host "Auditando métodos de autenticación en $total usuarios..." -ForegroundColor Yellow

foreach ($u in $users) {
    $i++
    Write-Progress -Activity "Auditando Métodos MFA" -Status "$($u.DisplayName)" -PercentComplete (($i / $total) * 100)

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
                    # Contraseña base estándar
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
        Write-Verbose "No se pudieron obtener métodos para $($u.UserPrincipalName): $_"
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

# --- Exportacion ---
if ($results.Count -gt 0) {
    Export-AdminReport -InputObject $results -ReportName "MFAStatusReport" -AutoOpen
}
else {
    Write-Warning "No se obtuvieron registros de usuarios."
}

Write-Host "Finalizado." -ForegroundColor Green
