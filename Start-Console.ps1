<#
.SYNOPSIS
    Direct entry point for M365 Toolkit Interactive Console.
#>
$consoleScript = Join-Path $PSScriptRoot "src\Scripts\Start-ExchangeConsole.ps1"
if (Test-Path $consoleScript) {
    & $consoleScript @args
} else {
    Write-Error "Start-ExchangeConsole.ps1 not found at $consoleScript"
}
