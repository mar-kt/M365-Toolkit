# Script para obtener estadísticas de buzones en Exchange Online
# [Refactored]: Uses _Bootstrap and Export-AdminReport

# ----------------- MODULE AUTO-LOADING -----------------
. $PSScriptRoot/_Bootstrap.ps1
# -------------------------------------------------------

# Conectar a Exchange Online (Module Function)
Connect-Exchange

Write-Host "Obteniendo estadísticas de buzones..." -ForegroundColor Cyan

# Obtener todos los buzones con sus estadísticas
$mailboxes = Get-Mailbox -ResultSize Unlimited | Where-Object { $_.RecipientTypeDetails -eq "UserMailbox" }

$results = @()

foreach ($mailbox in $mailboxes) {
    Write-Host "Procesando: $($mailbox.DisplayName)..." -ForegroundColor Yellow
    
    # Obtener estadísticas del buzón principal
    $stats = Get-MailboxStatistics -Identity $mailbox.UserPrincipalName -ErrorAction SilentlyContinue
    
    # Obtener estadísticas del buzón de archivo (si existe)
    $archiveStats = $null
    if ($mailbox.ArchiveStatus -eq "Active") {
        $archiveStats = Get-MailboxStatistics -Identity $mailbox.UserPrincipalName -Archive -ErrorAction SilentlyContinue
    }
    
    $result = [PSCustomObject]@{
        displayName        = $mailbox.DisplayName
        primaryEmail       = $mailbox.PrimarySmtpAddress
        primaryMailboxSize = if ($stats) { $stats.TotalItemSize.ToString() } else { "N/A" }
        archiveMailboxSize = if ($archiveStats) { $archiveStats.TotalItemSize.ToString() } else { "N/A" }
        totalItemCount     = if ($stats) { $stats.ItemCount } else { 0 }
    }
    
    $results += $result
}

# Export
Export-AdminReport -InputObject $results -ReportName "SimpleMailboxStats" -AutoOpen
Write-Host "Done."

