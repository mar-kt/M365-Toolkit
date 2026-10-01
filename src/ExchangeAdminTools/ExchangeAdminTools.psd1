@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'ExchangeAdminTools.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = '8e6dfd15-9c88-4e1b-b461-8742d45b5c92'

    # Author of this module
    Author            = 'SysAdmin Toolkit'

    # Description of the functionality provided by this module
    Description       = 'M365 Toolkit - Multi-tenant tools for Exchange Online, Microsoft Graph and Compliance administration.'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @('ExchangeOnlineManagement')

    # Functions to export from this module
    FunctionsToExport = @(
        'Connect-Exchange',
        'Connect-M365Graph',
        'Disconnect-M365',
        'ConvertTo-Gb',
        'Export-AdminReport'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport   = @()
}
