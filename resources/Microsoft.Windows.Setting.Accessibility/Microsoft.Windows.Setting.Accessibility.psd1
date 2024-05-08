@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'Microsoft.Windows.Setting.Accessibility.psm1'

    # Version number of this module.
    ModuleVersion        = '0.0.1'

    # ID used to uniquely identify this module
    GUID                 = '25cce770-4f0a-4387-a26b-4be692e229f9'

    # Author of this module
    Author               = 'v-cbrennan'

    # Company or vendor of this module
    CompanyName          = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright            = '(c) Microsoft Corp. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'DSC module for accessibility'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion    = '7.2'

    # DSC resources to export from this module
    DscResourcesToExport = @(
        'TextSize',
        'MousePointerSize',
        'ColorFilterSettings',
        'CursorIndicatorSettings'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_TextSize',
                'PSDscResource_MousePointerSize',
                'PSDscResource_ColorFilterSettings',
                'PSDscResource_CursorIndicatorSettings'
            )
    
            # Prerelease string of this module
            Prerelease = 'alpha'
        }

    } # End of PrivateData hashtable

}
