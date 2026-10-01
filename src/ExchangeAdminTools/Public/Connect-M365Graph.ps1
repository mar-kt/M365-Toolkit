function Connect-M365Graph {
    <#
    .SYNOPSIS
        Ensures an active Microsoft Graph session with minimum required permissions.
    .DESCRIPTION
        Checks if an active Microsoft Graph context already exists.
        If not, connects using Connect-MgGraph requesting the necessary delegated scopes.
    .PARAMETER Scopes
        Array of required permissions. Default: User.Read.All, UserAuthenticationMethod.Read.All, Organization.Read.All.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Scopes = @('User.Read.All', 'UserAuthenticationMethod.Read.All', 'Organization.Read.All')
    )

    process {
        Write-Verbose "Checking for active Microsoft Graph session..."

        $connected = $false
        try {
            if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                $context = Get-MgContext -ErrorAction SilentlyContinue
                if ($context -and $context.Account) {
                    $connected = $true
                }
            }
        }
        catch {
            $connected = $false
        }

        if ($connected) {
            Write-Verbose "Active Microsoft Graph session found for: $($context.Account)"
            Write-Host "Active Microsoft Graph session: $($context.Account)" -ForegroundColor Green
        }
        else {
            Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
            try {
                Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
                $newContext = Get-MgContext -ErrorAction SilentlyContinue
                Write-Host "Connected successfully to Microsoft Graph as: $($newContext.Account)" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to connect to Microsoft Graph: $_"
                throw
            }
        }
    }
}
