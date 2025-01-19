@{
    RootModule           = 'Microsoft.Windows.Setting.Bluetooth.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '65990ca0-278d-47b4-bc00-8fe47567e42d'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corporation. All rights reserved.'
    Description          = 'DSC Resource for Windows Setting Bluetooth'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'USB',
        'PenWindowsInk',
        'Mouse'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_USB',
                'PSDscResource_PenWindowsInk',
                'PSDscResource_Mouse'
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
