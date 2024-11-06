$global:WindowsUpdateSettingPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
# The network service account using wmiprvse.exe sets values in the user hive. This is the path to the Delivery Optimization settings in the user hive.
# It requires elevation to read the values
# Other settings might be needed e.g. DownloadRateForegroundProvider, DownloadRateBackgroundProvider
$global:DeliveryOptimizationSettingPath = 'Registry::HKEY_USERS\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings'

#region Functions
function DoesRegistryKeyPropertyExist {
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

function Test-WindowsUpdateRegistryKey {
    param (
        [Parameter(Mandatory)]
        [hashtable] $RegistryKeyProperty,

        [Parameter(Mandatory)]
        [WindowsUpdate]$CurrentState
    )

    $result = $true
    foreach ($key in $RegistryKeyProperty.Keys) {
        $value = $RegistryKeyProperty[$key]
        if ($value -ne $CurrentState.$key) {
            $result = $false
        }
    }

    return $result
}

function Set-WindowsUpdateRegistryKey {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [AllowNull()]
        [hashtable] $RegistryKeyProperty
    )

    if (-not (Test-Path -Path $Path)) {
        $null = New-Item -Path $Path -Force
    }

    foreach ($key in $RegistryKeyProperty.Keys) {
        $value = $RegistryKeyProperty[$key]
        $typeInfo = $value.GetType().Name

        if ($typeInfo -eq 'Boolean') {
            $value = [int]$value
        }

        if (-not (DoesRegistryKeyPropertyExist -Path $Path -Name $key)) {
            $null = New-ItemProperty -Path $Path -Name $key -Value $value -PropertyType 'DWord' -Force  
        }

        Write-Verbose -Message "Setting $key to $($RegistryKeyProperty[$key])"
        Set-ItemProperty -Path $Path -Name $key -Value $value
    }
} 

function Assert-DownloadRate {
    param (
        [Parameter(Mandatory)]
        [hashtable] $Parameters
    )

    if ($Parameters.ContainsKey('DownloadRateBackgroundPct') -or $Parameters.ContainsKey('DownloadRateForegroundPct')) {
        if ($Parameters.ContainsKey('DownloadRateBackgroundBps') -or $Parameters.ContainsKey('DownloadRateForegroundBps')) {
            Throw 'Cannot set both DownloadRateBackgroundPct/DownloadRateForegroundPct and DownloadRateBackgroundBps/DownloadRateForegroundBps'
        }
    }
}

function Initialize-WindowsUpdate {
    $class = [WindowsUpdate]::new()

    $hiddenProperties = $class | Get-Member -Static -Force | Where-Object { $_.MemberType -eq 'Property' } | Select-Object -ExpandProperty Name

    foreach ($p in $hiddenProperties) {
        $classPropertyName = $p.Replace('Property', '')
        $dataType = $class | Get-Member | Where-Object { $_.Name -eq $classPropertyName } | Select-Object -ExpandProperty Definition | Select-String -Pattern '\[.*\]' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value

        $currentValue = [WindowsUpdate]::GetRegistryValue($class::$p)
        if ($null -eq $currentValue) {
            if ($dataType -eq '[bool]') {
                $currentValue = $false
            }

            if ($dataType -eq '[int]') {
                $currentValue = 0
            }
        }
        
        $class.$classPropertyName = $currentValue
    }

    return $class
}
#endregion Functions

#region Classes
<#
.SYNOPSIS
    The `WindowsUpdate` DSC resource allows you to configure various Windows Update settings, including enabling or disabling specific update services, setting download and upload rates, and configuring active hours for updates.

.PARAMETER SID
    The security identifier. This is a key property and should not be set manually.

.PARAMETER IsContinuousInnovationOptedIn
    Indicates whether the device is opted in for continuous innovation updates. This is the setting in Windows Update settings -> Get the latest updates as soon as they're available.

.PARAMETER AllowMUUpdateService
    Indicates whether the Microsoft Update service is allowed. This is the setting in Windows Update settings -> Advanced options -> Receive updates for other Microsoft products.

.PARAMETER IsExpedited
    Indicates whether the updates are expedited. This is the setting in Windows Update settings -> Advanced options -> Get me up to date.

.PARAMETER AllowAutoWindowsUpdateDownloadOverMeteredNetwork
    Indicates whether automatic Windows Update downloads are allowed over metered networks. This is the setting in Windows Update settings -> Advanced options -> Download updates over metered connections.

.PARAMETER RestartNotificationsAllowed
    Indicates whether restart notifications are allowed. This is the setting in Windows Update settings -> Advanced options -> Notify me when a restart is required to finish updating.

.PARAMETER SmartActiveHoursState
    Indicates whether smart active hours are enabled.

.PARAMETER UserChoiceActiveHoursEnd
    The end time for user-chosen active hours.

.PARAMETER UserChoiceActiveHoursStart
    The start time for user-chosen active hours.

.PARAMETER DownloadMode
    The download mode for updates. Valid values are 0, 1, and 3. This is the setting in Windows Update settings -> Advanced options -> Delivery Optimization -> Allow downloads from other PCs.

.PARAMETER DownloadRateBackgroundBps
    The background download rate in bits per second.

.PARAMETER DownloadRateForegroundBps
    The foreground download rate in bits per second.

.PARAMETER DownloadRateBackgroundPct
    The background download rate as a percentage.

.PARAMETER DownloadRateForegroundPct
    The foreground download rate as a percentage.

.PARAMETER UploadLimitGBMonth
    The upload limit in gigabytes per month.

.PARAMETER UpRatePctBandwidth
    The upload rate as a percentage of bandwidth.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name WindowsUpdate -Method Get -ModuleName Microsoft.Windows.Setting.WindowsUpdate -Property @{}

    This command gets the current Windows Update settings.
#>
[DSCResource()]
class WindowsUpdate {
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
    [ValidateRange(0, 24)]
    [nullable[int]] $UserChoiceActiveHoursEnd

    [DscProperty()]
    [ValidateRange(0, 24)]
    [nullable[int]] $UserChoiceActiveHoursStart

    [DscProperty()]
    [ValidateSet(0, 1, 3)]
    [nullable[int]] $DownloadMode

    [DscProperty()]
    [nullable[int]] $DownloadRateBackgroundBps

    [DscProperty()]
    [nullable[int]] $DownloadRateForegroundBps

    [DscProperty()]
    [ValidateRange(0, 100)]
    [nullable[int]] $DownloadRateBackgroundPct

    [DscProperty()]
    [ValidateRange(0, 100)]
    [nullable[int]] $DownloadRateForegroundPct

    [DscProperty()]
    [ValidateRange(5, 500)]
    [nullable[int]] $UploadLimitGBMonth
    
    [DscProperty()]
    [ValidateRange(0, 100)]
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

    [WindowsUpdate] Get() {
        $currentState = Initialize-WindowsUpdate
        
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        $settableProperties = $this.GetParameters()
        return (Test-WindowsUpdateRegistryKey -RegistryKeyProperty $settableProperties -CurrentState $currentState)
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $parameters = $this.GetParameters()

        Assert-DownloadRate -Parameters $parameters

        Set-WindowsUpdateRegistryKey -Path $global:WindowsUpdateSettingPath -RegistryKeyProperty $parameters
    }

    #region WindowsUpdate helper functions
    static [object] GetRegistryValue($PropertyName) {
        $value = $null
        if ($null -ne $PropertyName) {
            if ((DoesRegistryKeyPropertyExist -Path $global:WindowsUpdateSettingPath -Name $PropertyName)) {
                $value = Get-ItemProperty -Path $global:WindowsUpdateSettingPath -Name $PropertyName | Select-Object -ExpandProperty $PropertyName
            } elseif ((DoesRegistryKeyPropertyExist -Path $global:DeliveryOptimizationSettingPath -Name $PropertyName)) {
                $value = Get-ItemProperty -Path $global:DeliveryOptimizationSettingPath -Name $PropertyName | Select-Object -ExpandProperty $PropertyName
            }
        }

        return $value
    }

    [hashtable] GetParameters() {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if (-not ([string]::IsNullOrEmpty($property.Value))) {
                $parameters[$property.Name] = $property.Value
            }
        }

        return $parameters
    }
    #endRegion WindowsUpdate helper functions
}
#endRegion classes