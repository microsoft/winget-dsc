# TODO: Add description
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
