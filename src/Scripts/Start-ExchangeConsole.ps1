<#
.SYNOPSIS
    Interactive Command Center for M365 Toolkit.
.DESCRIPTION
    Provides a simple text-based menu to access reports, search, identity and backup tools.
#>

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

# Initialize default client name if not set
if (-not $global:M365ToolkitClientName) {
    $global:M365ToolkitClientName = "General"
}

function Show-Menu {
    Clear-Host
    $activeClient = if ($global:M365ToolkitClientName) { $global:M365ToolkitClientName } else { "General" }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "         M365 ADMIN TOOLKIT             " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " [Cliente Activo: $activeClient]" -ForegroundColor Magenta
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host " 1. Reporte de Buzones y Cuotas (Excel)"
    Write-Host " 2. Buscar y Exportar Archivos (Purview KQL)"
    Write-Host " 3. Reciclar Cuenta / Traspaso de Identidad"
    Write-Host " 4. Auditar Reenvíos de Correo (Seguridad)"
    Write-Host " 5. Detectar Buzones Inactivos (>90 días)"
    Write-Host " 6. Auditar Permisos Delegados (FullAccess/SendAs)"
    Write-Host " 7. Rastrear Entrega de Correo (MessageTrace)"
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host " 8. Dashboard de Backups Locales (Salud)"
    Write-Host " 9. Indexador de Backups SQLite"
    Write-Host "10. Buscar en Backups Locales (Desconectado)"
    Write-Host "11. Verificación de Salud (Health Check)"
    Write-Host "12. Reporte de Licencias M365 (Graph)"
    Write-Host "13. Reporte de Estado MFA Moderno (Graph)"
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host " C. Cambiar Cliente / Perfil"
    Write-Host " D. Desconectar Sesiones (Limpiar credenciales)"
    Write-Host " Q. Salir"
    Write-Host "========================================" -ForegroundColor Cyan
}

do {
    Show-Menu
    $choice = Read-Host "Seleccione una opción"

    switch ($choice) {
        '1' {
            Write-Host "`nLanzando Reporte de Buzones..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MailboxSizeReport.ps1"
            
            $incArchive = Read-Host "¿Incluir buzones de archivo histórico? (Y/N) [Default: N]"
            $params = @{}
            if ($incArchive -eq 'Y' -or $incArchive -eq 'y') { $params['archive'] = $true }

            & $scriptPath @params
            Pause
        }
        '2' {
            Write-Host "`nLanzando Búsqueda y Exportación de Archivos..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Start-ArchiveSearch.ps1"
            & $scriptPath
            Pause
        }
        '3' {
            Write-Host "`nLanzando Herramienta de Actualización de Identidad..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Update-UserIdentity.ps1"
            & $scriptPath
            Pause
        }
        '4' {
            Write-Host "`nIniciando Auditoría de Reenvíos..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-ForwardingReport.ps1"
            & $scriptPath
            Pause
        }
        '5' {
            Write-Host "`nIniciando Búsqueda de Buzones Inactivos..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-StaleMailboxes.ps1"
            
            $days = Read-Host "Umbral de días de inactividad [Default: 90]"
            if (-not $days) { $days = 90 }
            & $scriptPath -Days $days
            Pause
        }
        '6' {
            Write-Host "`nIniciando Auditoría de Permisos..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MailboxPermissionReport.ps1"
            & $scriptPath
            Pause
        }
        '7' {
            Write-Host "`nIniciando Rastreo de Correo..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Search-DeliveryStatus.ps1"
            
            $s = Read-Host "Dirección del Remitente (Sender)"
            $r = Read-Host "Dirección del Destinatario (Recipient)"
            if ($s -and $r) {
                & $scriptPath -Sender $s -Recipient $r
            }
            else {
                Write-Warning "Tanto el remitente como el destinatario son requeridos."
            }
            Pause
        }
        '8' {
            Write-Host "`nCargando Dashboard de Backups..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-BackupReport.ps1"
            & $scriptPath
            Pause
        }
        '9' {
            Write-Host "`nIniciando Indexador de Respaldos..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Index-Backups.ps1"
            
            $root = Read-Host "Ruta al directorio de Backups (e.g. C:\Backups o /mnt/Backups)"
            if ($root) { & $scriptPath -BackupRoot $root }
            Pause
        }
        '10' {
            Write-Host "`nIniciando Búsqueda en Backups Locales..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Search-Backups.ps1"
            
            $root = Read-Host "Ruta al directorio de Backups"
            if ($root) {
                $subj = Read-Host "Palabra clave en Asunto (Opcional)"
                $snd = Read-Host "Remitente (Opcional)"
                & $scriptPath -BackupRoot $root -Subject $subj -From $snd
            }
            Pause
        }
        '11' {
            Write-Host "`nEjecutando Verificación de Salud..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Test-HealthCheck.ps1"
            & $scriptPath
            Pause
        }
        '12' {
            Write-Host "`nGenerando Reporte de Licencias (Microsoft Graph)..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-LicenseReport.ps1"
            & $scriptPath
            Pause
        }
        '13' {
            Write-Host "`nGenerando Reporte de Estado MFA (Microsoft Graph)..." -ForegroundColor Yellow
            $scriptPath = Join-Path $PSScriptRoot "Get-MFAStatusReport.ps1"
            & $scriptPath
            Pause
        }
        'C' -or 'c' {
            $newClient = Read-Host "Ingrese el nuevo nombre o identificador del Cliente [Actual: $global:M365ToolkitClientName]"
            if ($newClient -and $newClient.Trim() -ne "") {
                $global:M365ToolkitClientName = $newClient.Trim()
                Write-Host "Cliente activo configurado a: $global:M365ToolkitClientName" -ForegroundColor Green
            }
            Start-Sleep -Seconds 1
        }
        'D' -or 'd' {
            Disconnect-M365
            Pause
        }
        'Q' -or 'q' {
            Write-Host "`n¡Hasta pronto!" -ForegroundColor Green
            return
        }
        Default {
            Write-Warning "Opción no válida."
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
