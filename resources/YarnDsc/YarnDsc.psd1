@{

RootModule = 'YarnDsc.psm1'
ModuleVersion = '0.0.1'
GUID = '6aaf009e-013a-4e41-9edf-619c601e02ef'
Author = 'Microsoft Corporation'
CompanyName = 'Microsoft Corporation'
Copyright = '(c) Microsoft Corporation. All rights reserved.'
Description = 'DSC Resource for Yarn'
PowerShellVersion = '7.2'
DscResourcesToExport = @(
    'YarnInstall'
)
PrivateData = @{
    PSData = @{
        Tags = @('PSDscResource_YarnInstall')
        Prerelease = 'alpha'
    }
}
}

