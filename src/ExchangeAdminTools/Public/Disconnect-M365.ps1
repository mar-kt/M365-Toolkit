function Disconnect-M365 {
    <#
    .SYNOPSIS
        Cleanly closes all active Exchange Online, Security & Compliance, and Microsoft Graph sessions.
    .DESCRIPTION
        Prevents credential token retention in memory cache and eliminates cross-tenant data leakage.
    #>
    [CmdletBinding()]
    param()

    process {
        Write-Host "Disconnecting active administrative sessions..." -ForegroundColor Yellow

        # 1. Disconnect Exchange Online and Security & Compliance (Purview IPPSSession)
        try {
            if (Get-Command Disconnect-ExchangeOnline -ErrorAction SilentlyContinue) {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                Write-Host "Exchange Online and IPPSSession disconnected." -ForegroundColor Green
            }
            Get-PSSession | Where-Object { $_.ConfigurationName -like "*Exchange*" -or $_.Name -like "*Exchange*" -or $_.Name -like "*Compliance*" } | Remove-PSSession -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Could not completely disconnect Exchange Online/Purview: $_"
        }

        # 2. Disconnect Microsoft Graph
        try {
            if (Get-Command Disconnect-MgGraph -ErrorAction SilentlyContinue) {
                Disconnect-MgGraph -ErrorAction SilentlyContinue
                Write-Host "Microsoft Graph disconnected." -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Could not disconnect Microsoft Graph: $_"
        }

        # Reset global client/output folder variables
        $global:M365ToolkitClientName = $null
        $global:M365ToolkitCustomOutputFolder = $null
        Write-Host "Sessions and environment state successfully reset." -ForegroundColor Green
    }
}
