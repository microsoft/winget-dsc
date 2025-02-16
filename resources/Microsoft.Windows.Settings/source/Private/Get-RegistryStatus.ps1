# TODO: Add description
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
                $errorMessage = $script:localizedData.RegistryManualManipulation_ErrorMessage -f $Path
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
        Write-Verbose -Message ($script:localizedData.GetRegistryKeyData_DefaultMessage -f $Status.Default, $Path)
        $Status.Default
    }

    return $Key
}
