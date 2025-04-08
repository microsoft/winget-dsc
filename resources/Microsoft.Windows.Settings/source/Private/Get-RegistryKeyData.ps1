<#
    .SYNOPSIS
        Retrieves data from the registry key data file for a specific registry key

        It uses the localized data 'RegistryKeyData.psd1' to retrieve the data

    .PARAMETER Key
        The key in the data file to retrieve registry key data for

    .PARAMETER OnlyKeyPath
        If specified, only the path and name of the registry key will be returned

    .EXAMPLE
        PS C:\> Get-RegistryKeyData -Key 'FindMyDevice'

    .EXAMPLE
        PS C:\> Get-RegistryKeyData -Key 'General' -OnlyKeyPath
#>
function Get-RegistryKeyData
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $OnlyKeyPath
    )

    $registryDataPath = Join-Path -Path $PSScriptRoot -ChildPath 'DSCResources\RegistryKeyData.psd1'
    Write-Verbose -Message ($script:localizedData.GetRegistryKeyData_SearchMessage -f $Key, $registryDataPath)
    $import = Import-PowerShellDataFile -Path $registryDataPath

    $entry = $import.$Key

    if ($OnlyKeyPath)
    {
        $entry = @{
            Path = $entry.Path
            Name = $entry.Name
        }
    }

    return $entry
}
