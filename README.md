# M365 Toolkit

A comprehensive, modular, and professional **PowerShell 7+** toolkit designed for advanced administration, security auditing, compliance (eDiscovery/Purview), and inventory reporting across **Microsoft 365 / Exchange Online** environments.

This repository was born from the combination of several tools I have created, gathered, or adapted over the years based on requests across various consulting engagements, and I used to carry them on a USB flash drive when performing on-site work. For this reason, I cannot directly credit everyone whose code or ideas I may have drawn from depending on the specific tool.

Designed for System Administration using Microsoft 365 with Business Standard licensing, common in smaller companies where challenges like mailbox storage limits and email backups can become problematic, or where rapid user administration is needed without relying on specialized or paid third-party connectors.

---

## Notes & Administrative Permissions

- Accounts used for administration should ideally have **Global Administrator** privileges to access all toolkit features. Creating a dedicated administrative account for this purpose is recommended.
- If Global Administrator access is unavailable, the minimum required permissions by function include:
  - **Exchange Online Plan 1** (or higher) license to access EWS.
  - Roles:
    - **Message Reviewer**: To read and inspect message items across user mailboxes.
    - **Security Reader**: To access audit logs and security-related telemetry.
    - **User Administrator**: To manage users and identity properties.
    - **eDiscovery Manager** (in Microsoft Purview): Mandatory to create and start Compliance Searches.
- Even with assigned roles, certain features may fail if they are strictly exclusive to Global Administrators or restricted by the active tenant licensing tier.
- You can, and should, always disconnect your sessions after you are done as a good security practice, even if the interactive console handles it for you:

```powershell
# Disconnect all the active Microsoft Graph and Exchange sessions
Disconnect-M365
# Disconnect all the active Exchange sessions
Disconnect-ExchangeOnline
# Disconnect all the active Microsoft Graph sessions
Disconnect-M365Graph
```

---

## About AI-Generated Content

Several scripts, sections of this documentation, and translations were updated or generated with the assistance of AI, primarily to modernize legacy cmdlets to the current Microsoft Graph API and SDK.

Because this toolkit originated from personal consulting engagements in Spanish and is maintained on an "as-needed" basis, you might still encounter areas in need of refinement. If something doesn't work for your tenant, feel free to fork the repository, tweak it, and submit a pull request.

---

## Key Features

### Security & Compliance
- **Forwarding Rules Audit** (`Get-ForwardingReport.ps1`): Identifies both admin-configured SMTP redirects (server-side) and user Inbox rules (client-side) forwarding or redirecting mail to external or unauthorized addresses.
- **Mailbox Delegation & Permissions Audit** (`Get-MailboxPermissionReport.ps1`): Scans `FullAccess` and `SendAs` permissions across all mailboxes, filtering out default system accounts and SIDs to highlight anomalous access.
- **Modern MFA Audit (Microsoft Graph)** (`Get-MFAStatusReport.ps1`): Inspects actual registered authentication methods (Microsoft Authenticator, FIDO2, Phone/SMS, Windows Hello), 100% compatible with modern Conditional Access policies and Security Defaults.
- **Online Archive Extraction (Purview / eDiscovery)** (`Start-ArchiveSearch.ps1`): Targeted engine to query and extract Online Archive mailboxes by translating EWS Base64 folder IDs into optimized hexadecimal KQL queries (`folderid:HEX`). It creates and initiates Purview export jobs ready for local backup downloads.

### Storage & Quotas
- **Detailed Mailbox Sizing Report** (`Get-MailboxSizeReport.ps1`): Analyzes primary mailbox size, dumpster/deleted items, Sent Items, quota free space, and Online Archive enablement and sizing.
- **Tenant-Isolated Reporting** (`Export-AdminReport.ps1`): Automatically detects the connected tenant (or accepts a custom output folder) and organizes styled Excel workbooks (via `ImportExcel`) or UTF-8 CSVs neatly by tenant and date (`output/<Tenant>/<YYYY-MM-DD>/`).

### Identity & Lifecycle Management
- **Account Recycling (Offboarding & Reassignment)** (`Update-UserIdentity.ps1`): Safely reassigns accounts to new employees by updating identity attributes, converting the previous employee's address into a secondary alias (`smtp:alias`) to retain historical mail, and purging stale personal directory metadata.
- **Stale Mailbox Detection** (`Get-StaleMailboxes.ps1`): Detects inactive mailboxes with no recent sign-in activity (>90 days) to reclaim unused licenses and optimize subscription costs.
- **Modern License Inventory (Microsoft Graph)** (`Get-LicenseReport.ps1`): Catalogs assigned license SKUs with friendly commercial product names (e.g., `ENTERPRISEPACK`, `SPE_E3`).

### Local Backups & Offline Search
- **SQLite Indexing** (`Index-Backups.ps1`): Indexes Purview compliance export packages (`.zip`) into a local relational database (`backups.db`).
- **Offline Message Search** (`Search-Backups.ps1`): Fast search engine querying historical emails by subject, sender, or recipient without requiring a continuous cloud connection.
- **Backup Health Dashboard** (`Get-BackupReport.ps1`): Verifies local archive integrity.

---

## Project Structure

```text
M365-Toolkit/
├── Start-Console.ps1             # Direct launcher for the interactive console
├── src/
│   ├── ExchangeAdminTools/       # Core reusable module
│   │   ├── ExchangeAdminTools.psd1 # Module manifest (v1.0.0)
│   │   ├── ExchangeAdminTools.psm1 # Dynamic function loader
│   │   └── Public/               # Exported public cmdlets
│   │       ├── Connect-Exchange.ps1
│   │       ├── Connect-M365Graph.ps1 # Scoped Microsoft Graph connection
│   │       ├── Disconnect-M365.ps1   # Clean session termination & cache wipe
│   │       ├── ConvertTo-Gb.ps1
│   │       └── Export-AdminReport.ps1 # Multi-client output routing
│   └── Scripts/                  # Operational tool suite
│       ├── _Bootstrap.ps1        # Deterministic module bootstrapper
│       ├── Start-ExchangeConsole.ps1 # Interactive CLI command center
│       ├── Test-HealthCheck.ps1  # Automated health and syntax verification
│       ├── Start-ArchiveSearch.ps1 # Targeted archive compliance search & export
│       ├── Index-Backups.ps1     # SQLite indexer for local backup ZIPs
│       ├── Search-Backups.ps1    # Offline search tool
│       ├── Get-BackupReport.ps1  # Backup health dashboard
│       ├── Get-MailboxSizeReport.ps1 # Sizing and storage quota analyzer
│       ├── Get-ForwardingReport.ps1  # Security forwarding auditor
│       ├── Get-MailboxPermissionReport.ps1 # Mailbox delegation auditor
│       ├── Get-StaleMailboxes.ps1    # Inactive mailbox scanner
│       ├── Get-LicenseReport.ps1     # Powered by Microsoft.Graph.Users
│       ├── Get-MFAStatusReport.ps1   # Powered by Microsoft.Graph.Identity.SignIns
│       ├── Update-UserIdentity.ps1   # Employee offboard & mailbox recycling
│       └── Search-DeliveryStatus.ps1 # Email delivery tracker (MessageTrace)
├── templates/                    # Report templates
│   └── MailboxReport.xltx
├── output/                       # Isolated output directory (Git-ignored)
│   └── <Client>/<YYYY-MM-DD>/   # Auto-organized export reports
└── docs/                         # Additional documentation
```

---

## Requirements

1. **PowerShell 7+** (`pwsh`)
2. **PowerShell Modules**:
   ```powershell
   # 1. Exchange Online Management (Mandatory)
   Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser

   # 2. Microsoft Graph (Lightweight sub-modules only)
   Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser
   Install-Module -Name Microsoft.Graph.Users -Scope CurrentUser
   Install-Module -Name Microsoft.Graph.Identity.SignIns -Scope CurrentUser

   # 2.1. Full Microsoft Graph (all modules, about 148 modules, not recommended)
   Install-Module -Name Microsoft.Graph -Scope CurrentUser

   # 3. Styled Excel Reports (Optional, highly recommended)
   Install-Module -Name ImportExcel -Scope CurrentUser
   ```

3. **External Tools**:
   - `sqlite3` (required only when indexing local backup archives into `backups.db`).

---

## Quick Start

### 1. Environment Verification
Validate that all modules and scripts load properly without syntax or import errors:
```powershell
./src/Scripts/Test-HealthCheck.ps1
```

### 2. Interactive Console
Launch the unified command center to select any administrative task through an intuitive CLI menu:
```powershell
./Start-Console.ps1
```

From the console you can:
- Press **`C`** to set or change the active Client profile (all exports will be routed to `output/<Client>/<Date>/`).
- Press **`D`** to disconnect sessions and purge cached tokens before switching to another tenant.

### 3. Direct Script Execution
Each tool can also be run independently with dedicated parameters:
```powershell
# Audit unauthorized or external forwarding rules
./src/Scripts/Get-ForwardingReport.ps1

# Modern MFA methods audit
./src/Scripts/Get-MFAStatusReport.ps1

# M365 license assignment inventory
./src/Scripts/Get-LicenseReport.ps1

# Find mailboxes inactive for more than 60 days
./src/Scripts/Get-StaleMailboxes.ps1 -Days 60

# Targeted Online Archive search and export
./src/Scripts/Start-ArchiveSearch.ps1 -UserUpn "user@company.com" -KickOffExport $true
```