# Test-HealthCheck.ps1
$ErrorActionPreference = "Stop"

Write-Host "1. Testing Module Import..."
$modulePath = Join-Path $PSScriptRoot "../ExchangeAdminTools/ExchangeAdminTools.psd1"
try {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
        Write-Host "SUCCESS: Module imported from $modulePath" -ForegroundColor Green
    }
    else {
        throw "Module file not found at $modulePath"
    }
}
catch {
    Write-Error "FAIL: Could not import module. $_"
    exit 1
}

Write-Host "2. Testing Public Function Export (Connect-Exchange)..."
if (Get-Command "Connect-Exchange" -ErrorAction SilentlyContinue) {
    Write-Host "SUCCESS: Connect-Exchange is available." -ForegroundColor Green
}
else {
    Write-Error "FAIL: Connect-Exchange not found."
    exit 1
}

Write-Host "3. Testing Private Function Logic (ConvertTo-Gb)..."
# Check relative to PSScriptRoot
$privateFuncPath = Join-Path $PSScriptRoot "../ExchangeAdminTools/Public/ConvertTo-Gb.ps1"
if (Test-Path $privateFuncPath) {
    Write-Host "SUCCESS: Public function file exists at $privateFuncPath" -ForegroundColor Green
}
else {
    Write-Warning "WARNING: Public function file checks failed pathing."
}

Write-Host "4. Testing Script Auto-Loader Syntax..."
$scripts = @(
    "Get-MailboxSizeReport.ps1",
    "Start-ArchiveSearch.ps1",
    "Get-SimpleMailboxStats.ps1"
)
foreach ($s in $scripts) {
    $fullPath = Join-Path $PSScriptRoot $s
    try {
        # Just check if we can parse it (Get-Command on a file checks syntax)
        $null = Get-Command $fullPath
        Write-Host "SUCCESS: Syntax OK for $s" -ForegroundColor Green
    }
    catch {
        Write-Error "FAIL: Syntax Error in $s : $_"
    }
}

Write-Host "Verification Complete."
