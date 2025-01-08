# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
@{
    RootModule           = 'Microsoft.Windows.Setting.Personalization.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '7b91df07-d95a-4234-b11c-7595f21c28fc'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corp. All rights reserved.'
    Description          = 'The DSC module for Windows Personalization'
    PowerShellVersion    = '7.4'
    DscResourcesToExport = @(
        'BackgroundPicture',
        'BackgroundSolidColor',
        'BackgroundWindowsSpotlight',
        'VisualEffect',
        'Audio',
        'TextCursor',
        'StickyKeys',
        'ToggleKeys',
        'FilterKeys',
        'EyeControl'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_BackgroundPicture',
                'PSDscResource_BackgroundSolidColor',
                'PSDscResource_BackgroundWindowsSpotlight'
            )

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/microsoft/winget-dsc/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/microsoft/winget-dsc'

            # Prerelease string of this module
            Prerelease = 'alpha'
        }
    }
}
