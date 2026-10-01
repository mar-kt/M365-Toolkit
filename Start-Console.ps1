<#
.SYNOPSIS
    Punto de entrada directo a M365 Toolkit Console.
#>
$consoleScript = Join-Path $PSScriptRoot "src\Scripts\Start-ExchangeConsole.ps1"
if (Test-Path $consoleScript) {
    & $consoleScript @args
} else {
    Write-Error "No se encontro Start-ExchangeConsole.ps1 en $consoleScript"
}
