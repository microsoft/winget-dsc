@{
    RootModule           = 'Microsoft.Windows.Developer.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '95b88c6a-1ebe-4c8d-aae5-c57368fa2b90'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corporation. All rights reserved.'
    Description          = 'DSC Resource for Windows'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'DeveloperMode',
        'OsVersion',
        'ShowSecondsInClock',
        'EnableDarkMode',
        'Taskbar',
        'WindowsExplorer',
        'UserAccessControl',
        'EnableRemoteDesktop',
        'EnableLongPathSupport',
        'PowerPlanSetting',
        'WindowsCapability',
        'NetConnectionProfile',
        'AdvancedNetworkSharingSetting',
        'FirewallRule'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_DeveloperMode',
                'PSDscResource_OsVersion',
                'PSDscResource_ShowSecondsInClock',
                'PSDscResource_EnableDarkMode',
                'PSDscResource_Taskbar',
                'PSDscResource_WindowsExplorer',
                'PSDscResource_UserAccessControl',
                'PSDscResource_EnableRemoteDesktop',
                'PSDscResource_EnableLongPathSupport',
                'PSDscResource_PowerPlanSetting',
                'PSDscResource_WindowsCapability',
                'PSDscResource_NetConnectionProfile',
                'PSDscResource_AdvancedNetworkSharingSetting',
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
