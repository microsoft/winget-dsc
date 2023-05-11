@{

RootModule = 'Microsoft.VisualStudio.DSC.psm1'
ModuleVersion = '0.0.1'
GUID = 'f2354900-bfac-4c8c-899e-408fb3ae3792'
Author = 'Microsoft Corporation'
CompanyName = 'Microsoft Corporation'
Copyright = '(c) Microsoft Corporation. All rights reserved.'
Description = 'A DSC resource for managing Visual Studio components and extensions'
PowerShellVersion = '7.2'
DscResourcesToExport = @(
    'InstallVSComponent'
    'InstallVSConfig'
    'InstallVSExtension'
)
PrivateData = @{
    PSData = @{
        Tags = @('PSDscResource_InstallVSComponent', 'PSDscResource_InstallVSConfig', 'PSDscResource_InstallVSExtension')
        Prerelease = 'alpha'
    }
}

}
