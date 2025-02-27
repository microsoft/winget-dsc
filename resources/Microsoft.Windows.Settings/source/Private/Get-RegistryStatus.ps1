<#
    .SYNOPSIS
        Retrieve the current status of a registry using key path and value

    .PARAMETER Path
        The path of the registry key.

    .PARAMETER Name
        The name(s) of the registry values to check

    .PARAMETER Status
        A hashtable containing possible statuses and their corresponding values.

    .EXAMPLE
        PS C:\> Get-RegistryStatus -Path 'HKLM:\1\2\3' -Name 'Setting1'

    .EXAMPLE
        PS C:\> Get-RegistryStatus -Path 'HKLM:\1\2\3' -Name 'Setting1', 'Setting2' -Status @{ 'Enabled' = 1; 'Disabled' = 0 }
#>
function Get-RegistryStatus
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Name,

        [Parameter()]
        [AllowNull()]
        [System.Collections.Hashtable]
        $Status
    )

    try
    {
        $registryValue = if ($Name.Count -gt 1)
        {
            $Name | ForEach-Object {
                Get-ItemPropertyValue -Path $Path -Name $_ -ErrorAction Stop
            }
        }
        else
        {
            Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop
        }
    }
    catch
    {
        # TODO: Localize the verbose message, not error
        Write-Verbose -Message $_.Exception.Message -Verbose
    }

    $Key = if ($registryValue -or $registryValue -eq 0)
    {
        if ($registryValue.Count -gt 1)
        {
            # Using Group-Object to count the number of unique values
            # If the count is greater than 1, then the registry key has been manually manipulated
            $groupCount = $registryValue | Group-Object
            if ($groupCount.Name.Count -ne 1)
            {
                $errorMessage = $script:localizedData.RegistryManualManipulationError -f $Path
                New-InvalidDataException `
                    -ErrorId 'RegistryManualManipulationError' `
                    -Message $errorMessage
            }

            # Return the first value as the registry value is the same
            $registryValue = $registryValue[0]
        }

        $Status.GetEnumerator() | Where-Object { $_.Value -eq $registryValue } | Select-Object -ExpandProperty Key
    }
    else
    {
        $Status.Default
    }

    return $Key
}
