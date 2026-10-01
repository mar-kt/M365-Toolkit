function ConvertTo-Gb {
    <#
    .SYNOPSIS
        Converts a size (ByteQuantifiedSize, string, or int) to Gigabytes (double).
    .DESCRIPTION
        Takes an input size and returns the size in GB rounded to 2 decimal places.
        Supports Exchange ByteQuantifiedSize objects natively.
    .PARAMETER Size
        The size to convert. Can be a number, a string (e.g., "1024 MB"), or a ByteQuantifiedSize object.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Size
    )

    $bytes = 0.0

    # Duck-typing: Check if it has the specific ToBytes method expected from Exchange objects
    if ($Size -ne $null -and $Size.PSObject.Methods['ToBytes']) {
        # Native Exchange Object (or compatible)
        $bytes = $Size.ToBytes()
    }
    elseif ($Size -match "^\d+(\.\d+)?$") {
        # Numeric byte count
        $bytes = [double]$Size
    }
    else {
        # String processing: Handle "Unlimited", "10 GB (1024 bytes)", etc.
        $str = $Size.ToString()

        if ($str -match "Unlimited") {
            # Represent "Unlimited" as 100,000 GB (100 TB) for numerical sorting/reporting
            return 100000.00
        }

        # Regex to capture value and unit
        # Matches: "49.5 GB" or "49.5 GB (123123 bytes)" -> Captures "49.5" and "GB"
        if ($str -match "^(?<val>[\d\.,]+)\s*(?<unit>[KMGT]B)?") {
            $valStr = $Matches['val'].Replace(',', '.') # Normalize decimal delimiter
            $unit = $Matches['unit']
            
            $val = 0.0
            if ([double]::TryParse($valStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val)) {
                switch ($unit) {
                    "TB" { $bytes = $val * 1TB }
                    "GB" { $bytes = $val * 1GB }
                    "MB" { $bytes = $val * 1MB }
                    "KB" { $bytes = $val * 1KB }
                    Default { $bytes = $val } # Raw bytes or no unit specified
                }
            }
        }
    }

    $gb = $bytes / 1GB
    return [Math]::Round($gb, 2)
}
