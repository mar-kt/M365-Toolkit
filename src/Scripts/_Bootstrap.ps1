# _Bootstrap.ps1
# Standard environment setup for all scripts in this folder.
$ErrorActionPreference = "Stop"

# --- Auto-Load Module Logic ---
$modulePath = Join-Path $PSScriptRoot "../ExchangeAdminTools/ExchangeAdminTools.psd1"

if (Test-Path $modulePath) {
    Try {
        # Import module without forcing reload to preserve state
        Import-Module $modulePath -ErrorAction Stop
        # Write-Verbose "ExchangeAdminTools loaded."
    }
    Catch {
        Write-Warning "Could not load ExchangeAdminTools from $modulePath"
        Write-Error $_
    }
}
else {
    Write-Warning "Module ExchangeAdminTools not found at $modulePath."
}
