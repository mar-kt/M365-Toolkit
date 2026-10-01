# Test-HealthCheck.ps1
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "     M365 TOOLKIT - HEALTH CHECK        " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Module Import
Write-Host "1. Testing Module Import..."
$modulePath = Join-Path $PSScriptRoot "../ExchangeAdminTools/ExchangeAdminTools.psd1"
try {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        Write-Host " [OK] Module successfully imported from $modulePath" -ForegroundColor Green
    }
    else {
        throw "Module file not found at $modulePath"
    }
}
catch {
    Write-Error " [FAIL] Could not import module: $_"
    exit 1
}

# 2. Testing Public Exported Functions
Write-Host "`n2. Testing Public Functions Export..."
$expectedFunctions = @(
    'Connect-Exchange',
    'Connect-M365Graph',
    'Disconnect-M365',
    'ConvertTo-Gb',
    'Export-AdminReport'
)

$missingFunctions = @()
foreach ($fn in $expectedFunctions) {
    if (Get-Command $fn -ErrorAction SilentlyContinue) {
        Write-Host " [OK] Function '$fn' is available." -ForegroundColor Green
    }
    else {
        Write-Host " [FAIL] Function '$fn' is missing!" -ForegroundColor Red
        $missingFunctions += $fn
    }
}

if ($missingFunctions.Count -gt 0) {
    Write-Error "Module verification failed: Missing $($missingFunctions.Count) function(s)."
    exit 1
}

# 3. Testing Scripts Syntax via AST Parser
Write-Host "`n3. Testing Script Syntax across all tools..."
$rootDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$scriptFiles = Get-ChildItem -Path $rootDir -Recurse -Filter "*.ps1" | Where-Object { $_.Name -ne "Test-HealthCheck.ps1" }

$syntaxErrors = 0
foreach ($s in $scriptFiles) {
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($s.FullName, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        Write-Host " [FAIL] Syntax error in $($s.FullName):" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "        Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
        }
        $syntaxErrors++
    }
    else {
        Write-Host " [OK] Syntax OK: $($s.Name)" -ForegroundColor Green
    }
}

if ($syntaxErrors -gt 0) {
    Write-Error "Found $syntaxErrors script syntax error(s)."
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " [PASSED] ALL HEALTH CHECKS COMPLETED!  " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
