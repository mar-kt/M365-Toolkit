function ConvertTo-Gb {
    <#
    .SYNOPSIS
        Converts a size (ByteQuantifiedSize or string/int) to Gigabytes (double).
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

    # Duck-typing: Check if it has the specific ToBytes method we expect from Exchange objects
    if ($Size -ne $null -and $Size.PSObject.Methods['ToBytes']) {
        # Native Exchange Object (or compatible)
        $bytes = $Size.ToBytes()
    }
    elseif ($Size -match "^\d+(\.\d+)?$") {
        # Simple Number (assume bytes)
        $bytes = [double]$Size
    }
    else {
        # String processing: Handle "Unlimited", "10 GB (1024 bytes)", etc.
        $str = $Size.ToString()

        if ($str -match "Unlimited") {
            # Return a large number or -1 to indicate unlimited? 
            # For reporting purposes, let's treat it as a very large number or just return the text "Unlimited" in a separate check?
            # But this function returns [double]. Let's just return 0 or a massive number? 
            # Usually 100TB is safe for "Unlimited" in graphs.
            return 100000.00
        }

        # Regex to capture value and unit
        # Matches: "49.5 GB" or "49.5 GB (123123 bytes)" -> Captures "49.5" and "GB"
        if ($str -match "^(?<val>[\d\.,]+)\s*(?<unit>[KMGT]B)?") {
            $valStr = $Matches['val'].Replace(',', '.') # Normalize decimal
            $unit = $Matches['unit']
            
            $val = 0.0
            if ([double]::TryParse($valStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val)) {
                switch ($unit) {
                    "TB" { $bytes = $val * 1TB }
                    "GB" { $bytes = $val * 1GB }
                    "MB" { $bytes = $val * 1MB }
                    "KB" { $bytes = $val * 1KB }
                    Default { $bytes = $val } # No unit or 'B'
                }
            }
        }
    }

    $gb = $bytes / 1GB
    return [Math]::Round($gb, 2)
}
