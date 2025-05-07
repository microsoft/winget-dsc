<#
    .SYNOPSIS
        Sets the status of specified registry value

    .PARAMETER Path
        The path of the registry key.

    .PARAMETER Name
        The names of the registry values to set.

    .PARAMETER Value
        The value to set for the registry values.

    .PARAMETER Type
        The type of the registry values. Valid values are 'String', 'DWord', 'QWord', 'Binary', 'MultiString', 'Unknown'.

    .EXAMPLE
        PS C:\> Set-RegistryStatus -Path 'HKLM:\1\2\3' -Name 'Setting1' -Value '1'

    .EXAMPLE
        PS C:\> Set-RegistryStatus -Path 'HKLM:\Software\MyApp' -Name 'Setting1', 'Setting2' -Value '1' -Type 'DWord'
#>
function Set-RegistryStatus
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string[]] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Value,

        [Parameter()]
        [ValidateSet('String', 'DWord', 'QWord', 'Binary', 'MultiString', 'Unknown')]
        [AllowNull()]
        [string] $Type
    )

    if (-not (Test-Path $Path))
    {
        New-Item -Path $Path -Force | Out-Null
    }

    $Name | ForEach-Object {
        $Params = @{
            Path  = $Path
            Value = $Value
            Name  = $_
            Force = $true

        }

        if (-not (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue))
        {
            if ([string]::IsNullOrEmpty($Type))
            {
                $Type = 'Dword'
            }

            # Include the property type
            $Params.Add('PropertyType', $Type)
            # TODO: Add localizations
            New-ItemProperty @Params | Out-Null
        }
        else
        {
            Set-ItemProperty @Params
        }
    }
}
