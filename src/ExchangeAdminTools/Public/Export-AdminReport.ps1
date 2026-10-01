function Export-AdminReport {
    <#
    .SYNOPSIS
        Estandariza el proceso de exportacion de reportes con aislamiento por cliente.
    .DESCRIPTION
        Recibe un conjunto de datos, genera la ruta de destino organizada por Cliente/Fecha
        dentro de la carpeta 'output/', comprueba si ImportExcel esta disponible y exporta a XLSX o CSV.
    .PARAMETER InputObject
        Datos a exportar (generalmente un array de PSCustomObjects).
    .PARAMETER ReportName
        Nombre base del reporte (ej: "MailboxSize"). Se le anadira timestamp.
    .PARAMETER ClientName
        Nombre o identificador del cliente para aislar los reportes en output/<ClientName>/<Fecha>/.
        Si no se indica, toma el valor de $global:M365ToolkitClientName o "General".
    .PARAMETER OutputDirectory
        Ruta personalizada explicita para el archivo de salida (anula el calculo automatico).
    .PARAMETER AutoOpen
        Si se especifica, intenta abrir el archivo generado (en plataformas compatibles).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string]$ReportName,

        [Parameter(Mandatory = $false)]
        [string]$ClientName = $global:M365ToolkitClientName,

        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory,

        [switch]$AutoOpen
    )

    process {
        if (-not $InputObject) {
            Write-Warning "Export-AdminReport: No hay datos para exportar."
            return
        }

        # 1. Resolucion de Nombres y Timestamp
        $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        $baseName = "$ReportName-$timestamp"

        # 2. Determinacion de Carpeta de Destino
        $targetDir = $null

        if ($OutputDirectory) {
            $targetDir = $OutputDirectory
        }
        else {
            # Intentar localizar la carpeta 'output' del Toolkit
            $toolkitRoot = Resolve-Path (Join-Path $PSScriptRoot "../../..") -ErrorAction SilentlyContinue
            $outputBase = if ($toolkitRoot) { Join-Path $toolkitRoot.Path "output" } else { $null }

            if ($outputBase -and (Test-Path $outputBase)) {
                $clientFolder = if ($ClientName -and $ClientName.Trim() -ne "") { $ClientName.Trim() } else { "General" }
                $targetDir = Join-Path $outputBase (Join-Path $clientFolder $dateFolder)
            }
            else {
                # Fallback clasico: Desktop o Directorio de usuario
                $desktopPath = [Environment]::GetFolderPath("Desktop")
                if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
                    $desktopPath = $HOME
                }
                $targetDir = $desktopPath
            }
        }

        # Crear carpeta de destino si no existe
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        # 3. Exportacion en Excel (ImportExcel) o CSV UTF-8
        $finalPath = $null

        if (Get-Module -ListAvailable -Name ImportExcel) {
            $xlsxPath = Join-Path $targetDir "$baseName.xlsx"
            Write-Host "Exportando reporte a Excel ($xlsxPath)..." -ForegroundColor Cyan
            
            try {
                $InputObject | Export-Excel -Path $xlsxPath -AutoSize -FreezeTopRow -TableStyle Medium13 -ErrorAction Stop
                Write-Host "[OK] Reporte Excel generado exitosamente: $xlsxPath" -ForegroundColor Green
                $finalPath = $xlsxPath
            }
            catch {
                Write-Warning "Fallo la exportacion a Excel: $_. Usando respaldo en CSV..."
                $csvPath = Join-Path $targetDir "$baseName.csv"
                $InputObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                Write-Host "[OK] Reporte CSV generado exitosamente: $csvPath" -ForegroundColor Green
                $finalPath = $csvPath
            }
        }
        else {
            $csvPath = Join-Path $targetDir "$baseName.csv"
            Write-Host "Exportando reporte a CSV ($csvPath)..." -ForegroundColor Cyan
            $InputObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] Reporte CSV generado exitosamente: $csvPath" -ForegroundColor Green
            $finalPath = $csvPath
        }

        # 4. Apertura automatica opcional
        if ($AutoOpen -and $finalPath -and $IsWindows) {
            try {
                Start-Process $finalPath
            }
            catch {
                Write-Verbose "No se pudo auto-abrir el archivo: $_"
            }
        }

        return $finalPath
    }
}
