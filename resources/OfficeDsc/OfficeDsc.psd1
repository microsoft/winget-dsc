@{
    RootModule           = 'OfficeDsc.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corporation. All rights reserved.'
    Description          = 'DSC Resource for Microsoft Office 365 Deployment'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'Office365Installer'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_Office365Installer'
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
