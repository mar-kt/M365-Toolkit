<#
.SYNOPSIS
    Genera un informe de licencias de Microsoft 365 asignadas a los usuarios.
.DESCRIPTION
    Utiliza el modulo moderno 'Microsoft.Graph.Users'.
    Mapea los SkuIds con los nombres de producto legibles de la organizacion (ej: ENTERPRISEPACK, O365_BUSINESS_PREMIUM).
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# --- Dependencia: Microsoft.Graph.Users ---
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Warning "Este script requiere el modulo 'Microsoft.Graph.Users'."
    $install = Read-Host "Desea instalarlo ahora para el usuario actual? (Y/N)"
    if ($install -eq 'Y') {
        Install-Module Microsoft.Graph.Users -Scope CurrentUser -Force
    }
    else {
        Write-Error "Falta el modulo Microsoft.Graph.Users. Abortando ejecucion."
        exit
    }
}

# --- Conexion con Microsoft Graph ---
Connect-M365Graph -Scopes @('User.Read.All', 'Organization.Read.All')

Write-Host "Consultando catálogo de licencias del tenant..." -ForegroundColor Cyan

# 1. Obtener SKUs suscritos para mapear SkuId a nombre legible
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
    Write-Verbose "No se pudo obtener el catalogo completo de SKUs: $_"
}

# 2. Obtener usuarios y sus licencias asignadas
Write-Host "Obteniendo usuarios y licencias asignadas..." -ForegroundColor Cyan

try {
    $users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,Department,UsageLocation,AssignedLicenses -ErrorAction Stop
}
catch {
    Write-Error "Error al consultar usuarios desde Microsoft Graph: $_"
    exit
}

$results = @()
$total = $users.Count
$i = 0

Write-Host "Procesando $total usuarios..." -ForegroundColor Yellow

foreach ($u in $users) {
    $i++
    Write-Progress -Activity "Auditando Licencias" -Status "$($u.DisplayName)" -PercentComplete (($i / $total) * 100)

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

# --- Exportacion ---
if ($results.Count -gt 0) {
    Export-AdminReport -InputObject $results -ReportName "LicenseReport" -AutoOpen
}
else {
    Write-Warning "No se encontraron usuarios en el tenant."
}

Write-Host "Finalizado." -ForegroundColor Green
