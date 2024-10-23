@{
    RootModule = 'Microsoft.VSCode.Dsc.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'baf2c585-d931-4089-8500-93a5b8de1741'
    Author = 'Microsoft Corporation'
    CompanyName = 'Microsoft Corporation'
    Copyright = '(c) Microsoft Corporation. All rights reserved.'
    Description = 'DSC Resource for Visual Studio Code'
    PowerShellVersion = '7.2'
    DscResourcesToExport = @(
        'VSCodeExtension',
        'VSCodeInstaller'
    )
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @(
                'PSDscResource_VSCodeExtension',
                'PSDscResource_VSCodeInstaller'
                )

            # Prerelease string of this module
            Prerelease = 'alpha'
        }
    }
}
