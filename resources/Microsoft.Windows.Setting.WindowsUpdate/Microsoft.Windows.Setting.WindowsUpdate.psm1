$global:WindowsUpdateSettingPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'

#region Functions
function DoesRegistryKeyPropertyExist
{
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name
    )

    # Get-ItemProperty will return $null if the registry key property does not exist.
    $itemProperty = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $itemProperty
}

function Test-WindowsUpdateRegistryKey 
{
    param (
        [Parameter(Mandatory)]
        [hashtable] $RegistryKeyProperty,

        [Parameter(Mandatory)]
        [WindowsUpdate]$CurrentState
    )

    $result = $true
    foreach ($key in $RegistryKeyProperty.Keys)
    {
        $value = $RegistryKeyProperty[$key]
        if ($value -ne $CurrentState.$key)
        {
            $result = $false
        }
    }

    return $result
}

function Set-WindowsUpdateRegistryKey
{
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [AllowNull()]
        [hashtable] $RegistryKeyProperty
    )

    if (-not (Test-Path -Path $Path))
    {
        $null = New-Item -Path $Path -Force
    }

    foreach ($key in $RegistryKeyProperty.Keys)
    {
        $value = $RegistryKeyProperty[$key]
        $typeInfo = $value.GetType().Name

        if ($typeInfo -eq 'Boolean')
        {
            $value = [int]$value
        }

        if ($typeInfo -eq 'Int32' -and $key -in @('UserChoiceActiveHoursEnd', 'UserChoiceActiveHoursStart'))
        {
            if ($value -notin (0..24))
            {
                Throw "Value for $key must be between 0 and 24"
            }
        }

        if (-not (DoesRegistryKeyPropertyExist -Path $Path -Name $key))
        {
            $null = New-ItemProperty -Path $Path -Name $key -Value $value -PropertyType 'DWord' -Force  
        }

        Write-Verbose -Message "Setting $key to $($RegistryKeyProperty[$key])"
        Set-ItemProperty -Path $Path -Name $key -Value $value
    }
}
#endregion Functions

#region Classes
[DSCResource()]
class WindowsUpdate
{
    # Key required. Do not set.
    [DscProperty(Key)] 
    [string] $SID
    
    [DscProperty()]
    [nullable[bool]] $IsContinuousInnovationOptedIn

    [DscProperty()]
    [nullable[bool]] $AllowMUUpdateService

    [DscProperty()]
    [nullable[bool]] $IsExpedited

    [DscProperty()]
    [nullable[bool]] $AllowAutoWindowsUpdateDownloadOverMeteredNetwork

    [DscProperty()]
    [nullable[bool]] $RestartNotificationsAllowed

    [DscProperty()]
    [nullable[bool]] $SmartActiveHoursState

    [DscProperty()]
    [nullable[int]] $UserChoiceActiveHoursEnd

    [DscProperty()]
    [nullable[int]] $UserChoiceActiveHoursStart

    # TODO: Add delivery options

    static hidden [string] $IsContinuousInnovationOptedInProperty = 'IsContinuousInnovationOptedIn'
    static hidden [string] $AllowMUUpdateServiceProperty = 'AllowMUUpdateService'
    static hidden [string] $IsExpeditedProperty = 'IsExpedited'
    static hidden [string] $AllowAutoWindowsUpdateDownloadOverMeteredNetworkProperty = 'AllowAutoWindowsUpdateDownloadOverMeteredNetwork'
    static hidden [string] $RestartNotificationsAllowedProperty = 'RestartNotificationsAllowed2'
    static hidden [string] $SmartActiveHoursStateProperty = 'SmartActiveHoursState'
    static hidden [string] $UserChoiceActiveHoursEndProperty = 'UserChoiceActiveHoursEnd'
    static hidden [string] $UserChoiceActiveHoursStartProperty = 'UserChoiceActiveHoursStart'

    [WindowsUpdate] Get()
    {
        $currentState = [WindowsUpdate]::new()
        $currentState.IsContinuousInnovationOptedIn = [WindowsUpdate]::GetIsContinuousInnovationOptedInStatus()
        $currentState.AllowMUUpdateService = [WindowsUpdate]::AllowMUUpdateServiceStatus()
        $currentState.IsExpedited = [WindowsUpdate]::IsExpeditedStatus()
        $currentState.AllowAutoWindowsUpdateDownloadOverMeteredNetwork = [WindowsUpdate]::AllowAutoWindowsUpdateDownloadOverMeteredNetworkStatus()
        $currentState.RestartNotificationsAllowed = [WindowsUpdate]::RestartNotificationsAllowedStatus()
        $currentState.SmartActiveHoursState = [WindowsUpdate]::SmartActiveHoursStateStatus()
        $currentState.UserChoiceActiveHoursEnd = [WindowsUpdate]::UserChoiceActiveHoursEndStatus()
        $currentState.UserChoiceActiveHoursStart = [WindowsUpdate]::UserChoiceActiveHoursStartStatus()
        
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        $settableProperties = $this.GetParameters()
        return (Test-WindowsUpdateRegistryKey -RegistryKeyProperty $settableProperties -CurrentState $currentState)
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        $parameters = $this.GetParameters()

        Set-WindowsUpdateRegistryKey -Path $global:WindowsUpdateSettingPath -RegistryKeyProperty $parameters
    }

    #region WindowsUpdate helper functions
    static [bool] GetIsContinuousInnovationOptedInStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::IsContinuousInnovationOptedInProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::IsContinuousInnovationOptedInProperty).IsContinuousInnovationOptedInProperty
            return $value
        }        
    }

    static [bool] AllowMUUpdateServiceStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::AllowMUUpdateServiceProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::AllowMUUpdateServiceProperty).AllowMUUpdateServiceProperty
            return $value
        }        
    }

    static [bool] IsExpeditedStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::IsExpeditedProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::IsExpeditedProperty).IsExpeditedProperty
            return $value
        }        
    }

    static [bool] AllowAutoWindowsUpdateDownloadOverMeteredNetworkStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::AllowAutoWindowsUpdateDownloadOverMeteredNetworkProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::AllowAutoWindowsUpdateDownloadOverMeteredNetworkProperty).AllowAutoWindowsUpdateDownloadOverMeteredNetworkProperty
            return $value
        }        
    }

    static [bool] RestartNotificationsAllowedStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::RestartNotificationsAllowedProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::RestartNotificationsAllowedProperty).RestartNotificationsAllowed
            return $value
        }        
    }

    static [bool] SmartActiveHoursStateStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::SmartActiveHoursStateProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::SmartActiveHoursStateProperty).SmartActiveHoursState
            return $value
        }        
    }

    static [int] UserChoiceActiveHoursEndStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::UserChoiceActiveHoursEndProperty)))
        {
            return $false
        }
        else
        {
            # there is some weird behaviour with integers in the registry, so we need to get the value from the property
            $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::UserChoiceActiveHoursEndProperty) | Select-Object -ExpandProperty UserChoiceActiveHoursEnd
            
            return $value
        }        
    }

    static [int] UserChoiceActiveHoursStartStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::UserChoiceActiveHoursStartProperty))) 
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name ([WindowsUpdate]::UserChoiceActiveHoursStartProperty) | Select-Object -ExpandProperty UserChoiceActiveHoursStart
            return $value
        }        
    }

    [hashtable] GetParameters()
    {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties)
        {
            if (-not ([string]::IsNullOrEmpty($property.Value)))
            {
                $parameters[$property.Name] = $property.Value
            }
        }

        return $parameters
    }
    #endRegion WindowsUpdate helper functions
}
#endRegion classes