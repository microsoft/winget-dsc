@{
    RootModule           = 'NpmDsc.psm1'
    ModuleVersion        = '0.0.1'
    GUID                 = '3f5b94bc-6b26-4263-871d-6226bdc85cea'
    Author               = 'ryfu-msft'
    CompanyName          = 'ryfu-msft'
    Copyright            = '(c) ryfu-msft. All rights reserved.'
    Description          = 'A DSC Resource Module for managing npm packages.'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'NpmPackage'
        'NpmInstall'
    )
    PrivateData          = @{
        PSData = @{
            Tags = @('PSDscResource_NpmPackage', 'PSDscResource_NpmInstall')
            Prerelease   = 'alpha'
        }
    }
}
