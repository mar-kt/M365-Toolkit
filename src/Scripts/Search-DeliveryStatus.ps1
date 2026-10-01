<#
.SYNOPSIS
    Quickly checks delivery status for a specific sender/recipient pair.
.DESCRIPTION
    Wraps Get-MessageTrace to provide a friendly delivery check.
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Sender Email Address")]
    [string]$Sender,

    [Parameter(Mandatory = $true, HelpMessage = "Recipient Email Address")]
    [string]$Recipient,

    [int]$Hours = 48
)

# --- Auto-Load Module Logic ---
. $PSScriptRoot/_Bootstrap.ps1
# ------------------------------

Connect-Exchange

$start = (Get-Date).AddHours(-$Hours)
Write-Host "Searching traces from past $Hours hours..." -ForegroundColor Cyan

try {
    $traces = Get-MessageTrace -SenderAddress $Sender -RecipientAddress $Recipient -StartDate $start -ErrorAction Stop
    
    if ($traces) {
        # Formatting for readability
        $traces | Select-Object Received, SenderAddress, RecipientAddress, Subject, Status, MessageTraceId | Format-Table -AutoSize
        
        Write-Host "Found $($traces.Count) records." -ForegroundColor Green
        
        # Check for failures
        $failed = $traces | Where-Object { $_.Status -eq "Failed" }
        if ($failed) {
            Write-Warning "ALERT: Found $($failed.Count) FAILED messages."
        }
    }
    else {
        Write-Warning "No traces found. Verify the email addresses and time range ($Hours hours)."
    }
}
catch {
    Write-Error "Failed to run trace: $_"
}

Write-Host "Done."
