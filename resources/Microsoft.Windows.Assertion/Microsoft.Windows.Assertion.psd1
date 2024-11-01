# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
@{
    RootModule           = 'Microsoft.Windows.Assertion.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'e3510ba2-cc19-4fb2-872a-a40833c30e58'
    Author               = 'Microsoft Corporation'
    CompanyName          = 'Microsoft Corporation'
    Copyright            = '(c) Microsoft Corp. All rights reserved.'
    Description          = 'DSC Module for ensuring the system meets certain specifications'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'OsEditionId',       
        'SystemArchitecture',
        'ProcessorArchitecture',
        'HyperVisorPresent',
        'OsInstallDate',
        'OsVersion',
        'CsManufacturer',
        'CsModel',
        'CsDomain',
        'PowerShellVersion',
        'PnPDevice'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_EditionID',                
                'PSDscResource_SystemArchitecture',
                'PSDscResource_HyperVisorPresent',
                'PSDscResource_OsInstallDate'
            )
    
            # Prerelease string of this module
            Prerelease = 'alpha'
        }
    }
}
