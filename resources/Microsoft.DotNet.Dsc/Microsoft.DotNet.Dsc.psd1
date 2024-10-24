@{
    RootModule           = 'Microsoft.DotNet.Dsc.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '2e883e78-1d91-4d08-9fc1-2a968e31009d'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corporation. All rights reserved.'
    Description          = 'DSC Resource for .NET SDK tool installer'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'DotNetToolPackage'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_DotNetToolPackage'
            )

            # Prerelease string of this module
            Prerelease = 'alpha'

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/microsoft/winget-dsc/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/microsoft/winget-dsc'

        }
    }
}
