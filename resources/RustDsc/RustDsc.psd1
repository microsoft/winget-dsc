@{
    RootModule           = 'RustDsc.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'ced413f1-d327-41fe-a01a-e03ed52d9bb1'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corporation. All rights reserved.'
    Description          = 'DSC Resource for Rust'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'CargoToolInstall'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_RustDsc'
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
