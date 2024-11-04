$global:WindowsUpdateSettingPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$global:DeliveryOptimizationSettingPath = 'Registry::HKEY_USERS\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings' # The network service account using wmiprvse.exe sets values in the user hive

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

        # validate the value of UserChoiceActiveHoursEnd and UserChoiceActiveHoursStart to be between 0 and 24
        Assert-UserChoiceValue -KeyName $key -Value $value

        # validate the value of DownloadRateBackgroundPct, DownloadRateForegroundPct and UpRatePctBandwith to be between 0 and 100
        Assert-RatePercentageValue -KeyName $key -Value $value

        # validate the value of UpRatePctBandwith to be between 5 and 500
        Assert-UpRateValue -KeyName $key -Value $value

        if (-not (DoesRegistryKeyPropertyExist -Path $Path -Name $key))
        {
            $null = New-ItemProperty -Path $Path -Name $key -Value $value -PropertyType 'DWord' -Force  
        }

        Write-Verbose -Message "Setting $key to $($RegistryKeyProperty[$key])"
        Set-ItemProperty -Path $Path -Name $key -Value $value
    }
} 

function Assert-UpRateValue 
{
    param (
        [Parameter(Mandatory)]
        [string] $KeyName,

        [Parameter(Mandatory)]
        [int] $Value
    )

    if ($KeyName -eq 'UpRatePctBandwidth' -and $Value -notin (5..500))
    {
        Throw "You are specifying a percentage value, which must be between 5 and 500. The value you provided is $Value. Please provide a value between 5 and 500."
    }
}

function Assert-RatePercentageValue
{
    param (
        [Parameter(Mandatory)]
        [string] $KeyName,

        [Parameter(Mandatory)]
        [int] $Value
    )

    if ($KeyName -in ('DownloadRateBackgroundPct', 'DownloadRateForegroundPct', 'UpRatePctBandwidth') -and $Value -notin (0..100))
    {
        # TODO: It might be beneficial to add `Reasons` and not throw, only return statement
        Throw "You are specifying a percentage value, which must be between 0 and 100. The value you provided is $Value. Please provide a value between 0 and 100."
    }
}

function Assert-UserChoiceValue 
{
    param (
        [Parameter(Mandatory)]
        [string] $KeyName,

        [Parameter(Mandatory)]
        [int] $Value
    )

    if ($KeyName -in ('UserChoiceActiveHoursEnd', 'UserChoiceActiveHoursStart') -and $Value -notin (0..24))
    {
        Throw "Value must be between 0 and 24"
    }
}

function Assert-DownloadRate
{
    param (
        [Parameter(Mandatory)]
        [hashtable] $Parameters
    )

    if ($Parameters.ContainsKey('DownloadRateBackgroundPct') -or $Parameters.ContainsKey('DownloadRateForegroundPct'))
    {
        if ($Parameters.ContainsKey('DownloadRateBackgroundBps') -or $Parameters.ContainsKey('DownloadRateForegroundBps'))
        {
            Throw "Cannot set both DownloadRateBackgroundPct/DownloadRateForegroundPct and DownloadRateBackgroundBps/DownloadRateForegroundBps"
        }
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

    [DscProperty()]
    [ValidateSet(0, 1, 3)]
    [nullable[int]] $DownloadMode

    [DscProperty()]
    [nullable[int]] $DownloadRateBackgroundBps

    [DscProperty()]
    [nullable[int]] $DownloadRateForegroundBps

    [DscProperty()]
    [nullable[int]] $DownloadRateBackgroundPct

    [DscProperty()]
    [nullable[int]] $DownloadRateForegroundPct

    [DscProperty()]
    [nullable[int]] $UploadLimitGBMonth
    
    [DscProperty()]
    [nullable[int]] $UpRatePctBandwidth

    static hidden [string] $IsContinuousInnovationOptedInProperty = 'IsContinuousInnovationOptedIn'
    static hidden [string] $AllowMUUpdateServiceProperty = 'AllowMUUpdateService'
    static hidden [string] $IsExpeditedProperty = 'IsExpedited'
    static hidden [string] $AllowAutoWindowsUpdateDownloadOverMeteredNetworkProperty = 'AllowAutoWindowsUpdateDownloadOverMeteredNetwork'
    static hidden [string] $RestartNotificationsAllowedProperty = 'RestartNotificationsAllowed2'
    static hidden [string] $SmartActiveHoursStateProperty = 'SmartActiveHoursState'
    static hidden [string] $UserChoiceActiveHoursEndProperty = 'UserChoiceActiveHoursEnd'
    static hidden [string] $UserChoiceActiveHoursStartProperty = 'UserChoiceActiveHoursStart'
    static hidden [string] $DownloadModeProperty = 'DownloadMode'
    static hidden [string] $DownloadRateBackgroundBpsProperty = 'DownloadRateBackgroundBps'
    static hidden [string] $DownloadRateForegroundBpsProperty = 'DownloadRateForegroundBps'
    static hidden [string] $DownloadRateBackgroundPctProperty = 'DownloadRateBackgroundPct'
    static hidden [string] $DownloadRateForegroundPctProperty = 'DownloadRateForegroundPct'
    static hidden [string] $UploadLimitGBMonthProperty = 'UploadLimitGBMonth'
    static hidden [string] $UpRatePctBandwidthProperty = 'UpRatePctBandwidth'

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
        $currentState.DownloadMode = [WindowsUpdate]::DownloadModeStatus()
        $currentState.DownloadRateBackgroundBps = [WindowsUpdate]::DownloadRateBackGroundBps()
        $currentState.DownloadRateForegroundBps = [WindowsUpdate]::DownloadRateForegroundBps()
        $currentState.DownloadRateBackgroundPct = [WindowsUpdate]::DownloadRateBackgroundPctStatus()
        $currentState.DownloadRateForegroundPct = [WindowsUpdate]::DownloadRateForegroundPctStatus()
        $currentState.UploadLimitGBMonth = [WindowsUpdate]::UploadLimitGBMonthStatus()
        $currentState.UpRatePctBandwidth = [WindowsUpdate]::UpRatePctBandwidthStatus()
        
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

        Assert-DownloadRate -Parameters $parameters

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

    static [int] DownloadModeStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadModeProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadModeProperty) | Select-Object -ExpandProperty DownloadMode
            return $value
        }        
    }

    static [int] DownloadRateBackGroundBps()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadRateBackGroundBpsProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadRateBackGroundBpsProperty) | Select-Object -ExpandProperty DownloadRateBackGroundBps
            return $value
        }        
    }

    static [int] DownloadRateForegroundBps()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadRateForegroundBpsProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadRateForegroundBpsProperty) | Select-Object -ExpandProperty DownloadRateForegroundBps
            return $value
        }        
    }

    static [int] DownloadRateBackgroundPctStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadRateBackgroundPctProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadRateBackgroundPctProperty) | Select-Object -ExpandProperty DownloadRateBackgroundPct
            return $value
        }        
    }

    static [int] DownloadRateForegroundPctStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadRateForegroundPctProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::DownloadRateForegroundPctProperty) | Select-Object -ExpandProperty DownloadRateForegroundPct
            return $value
        }        
    }

    static [int] UploadLimitGBMonthStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::UploadLimitGBMonthProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::UploadLimitGBMonthProperty) | Select-Object -ExpandProperty UploadLimitGBMonth
            return $value
        }        
    }

    static [int] UpRatePctBandwidthStatus()
    {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::UpRatePctBandwidthProperty)))
        {
            return $false
        }
        else
        {
            $value = Get-ItemProperty -Path $global:DeliveryOptimizationSettingPath -Name ([WindowsUpdate]::UpRatePctBandwidthProperty) | Select-Object -ExpandProperty UpRatePctBandwidth
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