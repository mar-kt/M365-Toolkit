function Export-AdminReport {
    <#
    .SYNOPSIS
        Standardizes the content export process for all Admin Tools.
    .DESCRIPTION
        Takes a dataset, generates a robust file path (handling cross-platform Desktop locations),
        checks if ImportExcel is available, and exports to either XLSX or CSV.
    .PARAMETER InputObject
        The data to export (usually an array of PSCustomObjects).
    .PARAMETER ReportName
        The base name of the report (e.g. "MailboxSize"). Date timestamp will be appended.
    .PARAMETER AutoOpen
        If specified, attempts to open the file after export (Windows only, usually).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [string]$ReportName,

        [switch]$AutoOpen
    )

    process {
        if (-not $InputObject) {
            Write-Warning "Export-AdminReport: No data to export."
            return
        }

        # 1. Path Resolution
        $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
        $baseName = "$ReportName-$timestamp"

        $desktopPath = [Environment]::GetFolderPath("Desktop")
        if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
            $desktopPath = $HOME
        }

        # 2. Determine Format
        if (Get-Module -ListAvailable -Name ImportExcel) {
            $xlsxPath = Join-Path $desktopPath "$baseName.xlsx"
            Write-Host "Exporting to Excel ($xlsxPath)..." -ForegroundColor Cyan
            
            try {
                $InputObject | Export-Excel -Path $xlsxPath -AutoSize -FreezeTopRow -TableStyle Medium13 -ErrorAction Stop
                Write-Host "Success! Report saved to: $xlsxPath" -ForegroundColor Green
            }
            catch {
                Write-Warning "Excel export failed: $_. Falling back to CSV."
                $csvPath = Join-Path $desktopPath "$baseName.csv"
                $InputObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                Write-Host "Success! Report saved to: $csvPath" -ForegroundColor Green
            }
        }
        else {
            $csvPath = Join-Path $desktopPath "$baseName.csv"
            Write-Host "Exporting to CSV ($csvPath)..." -ForegroundColor Cyan
            $InputObject | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "Success! Report saved to: $csvPath" -ForegroundColor Green
        }
    }
}
