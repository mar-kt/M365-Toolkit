# ExchangeAdminTools.psm1

# Import Private Functions
$privateFolder = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privateFolder) {
    Get-ChildItem -Path $privateFolder -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
}

# Import Public Functions
$publicFolder = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicFolder) {
    Get-ChildItem -Path $publicFolder -Filter '*.ps1' | ForEach-Object {
        . $_.FullName
    }
}

# Export Public Functions
# This assumes that the filename of the public script matches the function name
$functionsToExport = Get-ChildItem -Path $publicFolder -Filter '*.ps1' | Select-Object -ExpandProperty BaseName
Export-ModuleMember -Function $functionsToExport
