# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
@{
    RootModule           = 'Microsoft.Windows.Setting.Accessibility.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '25cce770-4f0a-4387-a26b-4be692e229f9'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corp. All rights reserved.'
    Description          = 'DSC Module for Windows Accessibility'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'Text',
        'Magnifier',
        'MousePointer',
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
                'PSDscResource_Text',
                'PSDscResource_Magnifier',
                'PSDscResource_MousePointer',
                'PSDscResource_VisualEffect',
                'PSDscResource_Audio',
                'PSDscResource_TextCursor',
                'PSDscResource_StickyKeys',
                'PSDscResource_ToggleKeys',
                'PSDscResource_FilterKeys',
                'PSDscResource_EyeControl'
            )

            # Prerelease string of this module
            Prerelease = 'alpha'
        }
    }
}
