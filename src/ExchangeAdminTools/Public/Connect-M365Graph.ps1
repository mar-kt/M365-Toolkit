function Connect-M365Graph {
    <#
    .SYNOPSIS
        Asegura una conexion activa con Microsoft Graph con los permisos minimos requeridos.
    .DESCRIPTION
        Comprueba si ya existe una sesion activa en el contexto de Microsoft Graph.
        Si no existe, se conecta usando Connect-MgGraph solicitando los scopes delegados necesarios.
    .PARAMETER Scopes
        Array con los permisos requeridos. Por defecto: User.Read.All, UserAuthenticationMethod.Read.All, Organization.Read.All.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Scopes = @('User.Read.All', 'UserAuthenticationMethod.Read.All', 'Organization.Read.All')
    )

    process {
        Write-Verbose "Comprobando sesion activa en Microsoft Graph..."

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
            Write-Verbose "Sesion de Microsoft Graph activa encontrada para: $($context.Account)"
            Write-Host "Sesion activa en Microsoft Graph: $($context.Account)" -ForegroundColor Green
        }
        else {
            Write-Host "Conectando a Microsoft Graph..." -ForegroundColor Cyan
            try {
                Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
                $newContext = Get-MgContext -ErrorAction SilentlyContinue
                Write-Host "Conectado exitosamente a Microsoft Graph como: $($newContext.Account)" -ForegroundColor Green
            }
            catch {
                Write-Error "Fallo al conectar con Microsoft Graph: $_"
                throw
            }
        }
    }
}
