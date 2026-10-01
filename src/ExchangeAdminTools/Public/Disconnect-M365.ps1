function Disconnect-M365 {
    <#
    .SYNOPSIS
        Cierra de forma limpia todas las sesiones activas de Exchange Online y Microsoft Graph.
    .DESCRIPTION
        Previene la retencion de credenciales en memoria cache y la mezcla de datos entre distintos clientes.
    #>
    [CmdletBinding()]
    param()

    process {
        Write-Host "Desconectando sesiones activas..." -ForegroundColor Yellow

        # 1. Desconectar Exchange Online e IPPSSession (Purview)
        try {
            if (Get-Command Disconnect-ExchangeOnline -ErrorAction SilentlyContinue) {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                Write-Host "Exchange Online e IPPSSession desconectados." -ForegroundColor Green
            }
            Get-PSSession | Where-Object { $_.ConfigurationName -like "*Exchange*" -or $_.Name -like "*Exchange*" -or $_.Name -like "*Compliance*" } | Remove-PSSession -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "No se pudo desconectar completamente Exchange Online/Purview: $_"
        }

        # 2. Desconectar Microsoft Graph
        try {
            if (Get-Command Disconnect-MgGraph -ErrorAction SilentlyContinue) {
                Disconnect-MgGraph -ErrorAction SilentlyContinue
                Write-Host "Microsoft Graph desconectado." -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "No se pudo desconectar Microsoft Graph: $_"
        }

        # Limpiar variable de cliente
        $global:M365ToolkitClientName = $null
        Write-Host "Sesiones y variables de entorno restablecidas exitosamente." -ForegroundColor Green
    }
}
