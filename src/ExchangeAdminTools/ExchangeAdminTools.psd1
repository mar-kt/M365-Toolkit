@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'ExchangeAdminTools.psm1'

    # Version number of this module.
    ModuleVersion     = '0.0.1'

    # ID used to uniquely identify this module
    GUID              = '12345678-abcd-1234-abcd-1234567890ab'

    # Author of this module
    Author            = 'Malkiret'

    # Description of the functionality provided by this module
    Description       = 'Common tools for Exchange Online Administration and Compliance.'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @('ExchangeOnlineManagement')

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Connect-Exchange', 'ConvertTo-Gb', 'Export-AdminReport')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()
}
