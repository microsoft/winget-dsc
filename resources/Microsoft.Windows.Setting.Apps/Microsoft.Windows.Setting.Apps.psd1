# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
@{
    RootModule           = 'Microsoft.Windows.Setting.Apps.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'ac5fb135-25ec-4029-b8d4-534216a9b6ea'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corp. All rights reserved.'
    Description          = 'The DSC module for Windows Apps'
    PowerShellVersion    = '7.4'
    DscResourcesToExport = @(
        'AdvancedAppSettings',
        'AppExecutionAliases',
        'AppsForWebsites'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_AdvancedAppSettings',
                'PSDscResource_AppExecutionAliases',
                'PSDscResource_AppsForWebsites'
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
