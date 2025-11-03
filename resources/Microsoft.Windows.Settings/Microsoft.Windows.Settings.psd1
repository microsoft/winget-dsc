@{
    RootModule           = 'Microsoft.Windows.Settings.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '3f686897-d354-4ffb-bd22-f859f6d1142e'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corporation. All rights reserved.'
    Description          = 'DSC Resource for Windows Settings'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'WindowsSettings',
        'WindowsCapability',
        'PowerPlanSetting',
        'AdvancedNetworkSharingSetting',
        'NetConnectionProfile',
        'FirewallRule'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_WindowsSettings',
                'PSDscResource_WindowsCapability',
                'PSDscResource_PowerPlanSetting',
                'PSDscResource_AdvancedNetworkSharingSetting',
                'PSDscResource_NetConnectionProfile',
                'PSDscResource_FirewallRule'
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
