@{
RootModule = 'Microsoft.Windows.Developer.psm1'
ModuleVersion = '0.1.0'
GUID = '95b88c6a-1ebe-4c8d-aae5-c57368fa2b90'
Author = 'Microsoft Corporation'
CompanyName = 'Microsoft Corporation'
Copyright = '(c) Microsoft Corporation. All rights reserved.'
Description = 'DSC Resource for Windows'
PowerShellVersion = '7.2'
DscResourcesToExport = @(
    'DeveloperMode',
    'OsVersion',
    'TaskBarAlignment',
    'ShowSecondsInClock',
    'HideFileExtensions',
    'ShowTaskViewButton',
    'ShowHiddenFiles',
    'HideTaskBarLabels',
    'EnableDarkMode'
)
PrivateData = @{
    PSData = @{
        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @(
            'PSDscResource_DeveloperMode',
            'PSDscResource_OsVersion',
            'PSDscResource_TaskBarAlignment',
            'PSDscResource_ShowSecondsInClock',
            'PSDscResource_HideFileExtensions',
            'PSDscResource_ShowTaskViewButton',
            'PSDscResource_ShowHiddenFiles',
            'PSDscResource_HideTaskBarLabels',
            'PSDscResource_EnableDarkMode'
            )

        # Prerelease string of this module
        Prerelease = 'alpha'
    }
}
}
