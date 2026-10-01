function Export-AdminReport {
    <#
    .SYNOPSIS
        Standardizes report exports with automated client and date-based isolation.
    .DESCRIPTION
        Takes a dataset, resolves the target destination directory under 'output/<ClientName>/<Date>/',
        checks if the ImportExcel module is available, and exports to either styled XLSX or UTF-8 CSV.
    .PARAMETER InputObject
        Data to export (typically an array of PSCustomObjects).
    .PARAMETER ReportName
        Base report name (e.g., "MailboxSize"). An execution timestamp will be appended.
    .PARAMETER ClientName
        Client identifier to isolate outputs in output/<ClientName>/<Date>/.
        Defaults to $global:M365ToolkitClientName or "General".
    .PARAMETER OutputDirectory
        Explicit custom output directory (overrides automatic path resolution).
    .PARAMETER AutoOpen
        If specified, attempts to open the generated report file (on supported platforms).
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
            Write-Warning "Export-AdminReport: No data to export."
            return
        }

        # 1. Name and Timestamp Resolution
        $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
        $dateFolder = Get-Date -Format "yyyy-MM-dd"
        $baseName = "$ReportName-$timestamp"

        # 2. Target Directory Resolution
        $targetDir = $null

        if ($OutputDirectory) {
            $targetDir = $OutputDirectory
        }
        else {
            # Locate toolkit output base directory
            $toolkitRoot = Resolve-Path (Join-Path $PSScriptRoot "../../..") -ErrorAction SilentlyContinue
            $outputBase = if ($toolkitRoot) { Join-Path $toolkitRoot.Path "output" } else { $null }

            if ($outputBase -and (Test-Path $outputBase)) {
                $clientFolder = if ($ClientName -and $ClientName.Trim() -ne "") { $ClientName.Trim() } else { "General" }
                $targetDir = Join-Path $outputBase (Join-Path $clientFolder $dateFolder)
            }
            else {
                # Fallback: User Desktop or Home folder
                $desktopPath = [Environment]::GetFolderPath("Desktop")
                if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
                    $desktopPath = $HOME
                }
                $targetDir = $desktopPath
            }
        }

        # Create target directory if it does not exist
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        # 3. Export to Excel (ImportExcel) or UTF-8 CSV
        $finalPath = $null

        if (Get-Module -ListAvailable -Name ImportExcel) {
            $xlsxPath = Join-Path $targetDir "$baseName.xlsx"
            Write-Host "Exporting report to Excel ($xlsxPath)..." -ForegroundColor Cyan
            
            try {
                $InputObject | Export-Excel -Path $xlsxPath -AutoSize -FreezeTopRow -TableStyle Medium13 -ErrorAction Stop
                Write-Host "[OK] Excel report successfully generated: $xlsxPath" -ForegroundColor Green
                $finalPath = $xlsxPath
            }
            catch {
                Write-Warning "Excel export failed: $_. Falling back to CSV..."
                $csvPath = Join-Path $targetDir "$baseName.csv"
                $InputObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                Write-Host "[OK] CSV report successfully generated: $csvPath" -ForegroundColor Green
                $finalPath = $csvPath
            }
        }
        else {
            $csvPath = Join-Path $targetDir "$baseName.csv"
            Write-Host "Exporting report to CSV ($csvPath)..." -ForegroundColor Cyan
            $InputObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "[OK] CSV report successfully generated: $csvPath" -ForegroundColor Green
            $finalPath = $csvPath
        }

        # 4. Optional Auto-Open
        if ($AutoOpen -and $finalPath -and $IsWindows) {
            try {
                Start-Process $finalPath
            }
            catch {
                Write-Verbose "Could not auto-open report file: $_"
            }
        }

        return $finalPath
    }
}
