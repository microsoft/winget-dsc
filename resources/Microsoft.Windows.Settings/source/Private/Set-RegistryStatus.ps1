# TODO: Add description
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
            Path = $Path
            Value = $Value
            Name = $_
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
