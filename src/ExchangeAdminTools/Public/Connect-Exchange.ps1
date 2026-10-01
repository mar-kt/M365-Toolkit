function Connect-Exchange {
    <#
    .SYNOPSIS
        Ensures a connection to Exchange Online exists.
    .DESCRIPTION
        Checks if a session is already active. If not, attempts to connect using Connect-ExchangeOnline.
    #>
    [CmdletBinding()]
    param()

    process {
        Write-Verbose "Checking for existing Exchange Online session..."
        
        # Robust check using the module's own cmdlet
        $connected = $false
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $info = Get-ConnectionInformation -ErrorAction SilentlyContinue
            if ($info) { 
                $connected = $true 
                Write-Verbose "Get-ConnectionInformation found active connection: $($info | Out-String)"
            }
        }
        # Fallback to PSSession check if Get-ConnectionInformation isn't available (older versions)
        if (-not $connected) {
            $sessions = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -or $_.Name -like '*ExchangeOnlineInternalSession*' }
            if ($sessions) { $connected = $true }
        }

        if ($connected) {
            Write-Verbose "Session found. Skipping new connection."
            Write-Verbose "Already connected to Exchange Online."
        }
        else {
            Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
            try {
                Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
                Write-Host "Connected successfully." -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to connect to Exchange Online: $_"
                throw
            }
        }
    }
}
