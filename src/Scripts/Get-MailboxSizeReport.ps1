<#
.SYNOPSIS
  Create report of all mailbox and archive sizes
.DESCRIPTION
  Collects all the mailbox and archive stats from Exchange Online users. By default it will also
  include the Shared Mailboxes. 
#>

param(
  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter the Exchange Online or Global admin username (Optional if already connected)"
  )]
  [string]$adminUPN = "",

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Get (only) Shared Mailboxes or not. Default include them"
  )]
  [ValidateSet("no", "only", "include")]
  [string]$sharedMailboxes = "include",

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Include Archive mailboxes"
  )]
  [switch]$archive,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Path to CSV file with email addresses"
  )]
  [string]$importCSV
)

# ----------------- MODULE AUTO-LOADING -----------------
. $PSScriptRoot/_Bootstrap.ps1
# -------------------------------------------------------

Function Get-Mailboxes {
  <#
    .SYNOPSIS
        Get all the mailboxes for the report
  #>
  process {
    if ($importCSV) {
      write-host "Using import CSV for email address" -ForegroundColor cyan

      $mailboxes = Import-CSV -path $importCSV -Header 'emailaddress' 
      
      ForEach ($mailbox in $mailboxes) {
        Get-EXOMailbox -Identity $mailbox.emailaddress -Properties IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase | 
        Select-Object UserPrincipalName, DisplayName, PrimarySMTPAddress, RecipientType, RecipientTypeDetails, IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase
      }
    }
    else {
      switch ($sharedMailboxes) {
        "include" { $mailboxTypes = "UserMailbox,SharedMailbox" }
        "only" { $mailboxTypes = "SharedMailbox" }
        "no" { $mailboxTypes = "UserMailbox" }
      }

      Get-EXOMailbox -ResultSize unlimited -RecipientTypeDetails $mailboxTypes -Properties IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase | 
      Select-Object UserPrincipalName, DisplayName, PrimarySMTPAddress, RecipientType, RecipientTypeDetails, IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase
    }
  }
}

Function Get-MailboxStats {
  <#
    .SYNOPSIS
        Get the mailbox size and quota
  #>
  process {
    $i = 0
    $mailboxes = Get-Mailboxes 
    $mailboxes | ForEach-Object {

      # Get mailbox size     
      $mailboxSize = Get-EXOMailboxStatistics -Identity $_.UserPrincipalName -Properties LastUserActionTime | Select-Object TotalItemSize, TotalDeletedItemSize, ItemCount, DeletedItemCount, LastUserActionTime

      if ($null -ne $mailboxSize) {
      
        # Get archive size if it exists and is requested
        $archiveSize = 0
        $archiveResult = $null

        if ($archive.IsPresent -and ($null -ne $_.ArchiveDatabase)) {
          $archiveResult = Get-EXOMailboxStatistics -UserPrincipalName $_.UserPrincipalName -Archive | Select-Object ItemCount, DeletedItemCount, @{Name = "TotalArchiveSize"; Expression = { $_.TotalItemSize } }
          if ($null -ne $archiveResult) {
            # Uses Module Function
            $archiveSize = ConvertTo-Gb -size $archiveResult.TotalArchiveSize
          }
        }

        # Get Sent Items 
        # Note: FolderScope handles localization. We assume the first result is the root Sent Items.
        $sentItemsRaw = Get-EXOMailboxFolderStatistics -Identity $_.UserPrincipalName -Folderscope sentitems -ErrorAction SilentlyContinue 
        # Pick the one that is actually the SentItems type (just in case subfolders appear)
        $sentItems = $sentItemsRaw | Where-Object { $_.FolderType -eq 'SentItems' } | Select-Object -First 1 | Select-Object ItemsInFolderAndSubfolders, @{
          Name       = "sentItemSize"; 
          Expression = { $_.FolderAndSubfolderSize }
        }
    
        # NOTE: Using ConvertTo-Gb from Module for all calculations below
        [pscustomobject]@{
          "Display Name"                     = $_.DisplayName
          "Email Address"                    = $_.PrimarySMTPAddress
          "Mailbox Type"                     = $_.RecipientTypeDetails
          "Last User Action Time"            = $mailboxSize.LastUserActionTime
          "Total Size (GB)"                  = ConvertTo-Gb -size $mailboxSize.TotalItemSize
          "Deleted Items Size (GB)"          = ConvertTo-Gb -size $mailboxSize.TotalDeletedItemSize
          "Item Count"                       = $mailboxSize.ItemCount
          "Deleted Items Count"              = $mailboxSize.DeletedItemCount
          "Mailbox Warning Quota (GB)"       = ConvertTo-Gb -size $_.IssueWarningQuota
          "Max Mailbox Size (GB)"            = ConvertTo-Gb -size $_.ProhibitSendReceiveQuota
          
          # Simplified Math using GB values directly
          "Mailbox Free Space (GB)"          = (ConvertTo-Gb -size $_.ProhibitSendReceiveQuota) - (ConvertTo-Gb -size $mailboxSize.TotalItemSize)
          
          "Sent Items Size (GB)"             = $(if ($null -ne $sentItems) { ConvertTo-Gb -size $sentItems.sentItemSize } else { '-' })
          "Sent Items Count"                 = $(if ($null -ne $sentItems) { $sentItems.ItemsInFolderAndSubfolders } else { '-' }) 
          "Archive Size (GB)"                = $(if ($null -ne $archiveResult) { ConvertTo-Gb -size $archiveResult.TotalArchiveSize } else { '-' })
          "Archive Items Count"              = $(if ($null -ne $archiveResult) { $archiveResult.ItemCount } else { '-' }) 
         
          "Archive Mailbox Free Space (GB)*" = $(if ($null -ne $archiveResult) { (ConvertTo-Gb -size $_.ArchiveQuota) - $archiveSize } else { '-' })
          
          "Archive Deleted Items Count"      = $(if ($null -ne $archiveResult) { $archiveResult.DeletedItemCount } else { '-' })
          "Archive Warning Quota (GB)"       = $(if ($null -ne $archiveResult) { ConvertTo-Gb -size $_.ArchiveWarningQuota } else { '-' })
          "Archive Quota (GB)"               = $(if ($null -ne $archiveResult) { ConvertTo-Gb -size $_.ArchiveQuota } else { '-' })
        }

        $currentUser = $_.DisplayName
        Write-Progress -Activity "Collecting mailbox status" -Status "Current Count: $i" -PercentComplete (($i / $mailboxes.Count) * 100) -CurrentOperation "Processing mailbox: $currentUser"
        $i++;
      }
    }
  }
}

# Connect using Module Function
Connect-Exchange

# Check for ImportExcel early to visualize dependency
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
  Write-Warning "RECOMMENDATION: Install 'ImportExcel' for colorful reports."
  Write-Warning "Run: Install-Module ImportExcel -Scope CurrentUser"
}

# Always run the report
$report = Get-MailboxStats
  
# --- Export Logic ---
# Optimized using Shared Module
Export-AdminReport -InputObject $report -ReportName "MailboxSizeReport" -AutoOpen

Write-Host "Done."
