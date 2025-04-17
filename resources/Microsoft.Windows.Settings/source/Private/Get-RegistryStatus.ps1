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
        PS C:\> Get-RegistryStatus -Path 'HKLM:\1\2\3' -Name 'Setting1', 'Setting2' -Status @{ 'Enabled' = 1; 'Disabled' = 0; 'Default' = 0 }
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

    # Grab the default value from the one matching in the status hashtable e.g. @{ 'Enabled' = 1; 'Disabled' = 0; 'Default' = 0 } <-- 'Disabled' will be returned
    $key = $status.GetEnumerator() | Where-Object { $_.Value -eq $Status.Default -and $_.Key -ne 'Default' } | Select-Object -ExpandProperty Key

    # For class we create variable
    New-Variable -Name 'registryValue' -Value $null -Scope Local -Force

    try
    {
        $registryValue = foreach ($NameItem in $Name)
        {
            Get-ItemPropertyValue -Path $Path -Name $NameItem -ErrorAction Stop
        }
    }
    catch
    {
        Write-Verbose -Message ($script:localizedData.GetRegistryStatus_DefaultMessage -f $Status.Default, $Name)
    }

    if (-not ([string]::IsNullOrEmpty($registryValue)))
    {
        if ($Status.ContainsKey('Default'))
        {
            # Remove the default value from the hashtable as it is returned by default if nothing is found
            $Status.Remove('Default')
        }

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

            # Return the first value as the registry value should be the same
            $registryValue = $registryValue[0]
        }

        $key = $Status.GetEnumerator() | Where-Object -Property Value -EQ $registryValue | Select-Object -ExpandProperty Key
    }

    return $Key
}
