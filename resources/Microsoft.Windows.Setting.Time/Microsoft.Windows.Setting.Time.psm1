if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:tzAutoUpdatePath = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'
    $global:SysTrayPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $global:AdditionalClockPath = 'HKCU:\Control Panel\TimeDate'
} else {
    $global:tzAutoUpdatePath = $global:SysTrayPath = $global:AdditionalClockPath = $env:TestRegistryPath
}

#region Functions
function TryGetRegistryValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Property
    )

    if (Test-Path -Path $Key) {
        try {
            return (Get-ItemProperty -Path $Key -Name $Property -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Property)
        } catch {
            Write-Verbose "Property `"$($Property)`" could not be found."
        }
    } else {
        Write-Verbose 'Registry key does not exist.'
    }
}
function Get-ValidTimeZone {
    param (
        [Parameter(Mandatory = $true)]
        [string] $TimeZone
    )

    try {
        $timeZoneId = (Get-TimeZone -Id $TimeZone -ErrorAction Stop).Id
    } catch {
        throw [System.Configuration.ConfigurationException]::new("Executing 'Get-TimeZone' failed. Error: $($PSItem.Exception.Message)")
    }

    return $timeZoneId
}
#endRegion Functions

#region Classes
<#
.SYNOPSIS
    This `Time` DSC Resource allows you to manage the time zone, automatic time zone update, and system tray date/time visibility settings on a Windows machine.

.DESCRIPTION
    This `Time` DSC Resource allows you to manage the time zone, automatic time zone update, and system tray date/time visibility settings on a Windows machine.

.PARAMETER TimeZone
    The time zone to set on the machine. The value should be a valid time zone ID from the list of time zones (Get-TimeZone -ListAvailable).Id. The default value is the current time zone.

.PARAMETER NotifyClockChange
    Whether to notify the user when the time changes. The value should be a boolean.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name Time -Method Set -Property @{ TimeZone = "Pacific Standard Time"}

    This example sets the time zone to Pacific Standard Time.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name Time -Method Get -Property {}

    This example gets the current time settings on the machine.
#>
[DscResource()]
class TimeZone {
    [DscProperty(Key)]
    [string] $TimeZone

    [DscProperty()]
    [nullable[bool]] $SetTimeZoneAutomatically

    static hidden [string] $SetTimeZoneAutomaticallyProperty = 'Type'

    [TimeZone] Get() {
        $currentState = [TimeZone]::New()
        $currentState.SetTimeZoneAutomatically = [TimeZone]::GetTimeZoneAutoUpdateStatus()
        $currentState.TimeZone = (Get-TimeZone).Id

        return $currentState
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $currentState = $this.Get()

        if ($currentState.SetTimeZoneAutomatically -ne $this.SetTimeZoneAutomatically) {
            $desiredState = $this.SetTimeAutomatically ? [TimeZone]::NtpEnabled : [TimeZone]::NtpDisabled

            Set-ItemProperty -Path $global:tzAutoUpdatePath -Name ([TimeZone]::SetTimeZoneAutomaticallyProperty) -Value $desiredState
        }

        if ($currentState.TimeZone -ne $this.TimeZone) {
            Set-TimeZone -Id (Get-ValidTimeZone -TimeZone $this.TimeZone)
        }
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.TimeZone) -and ($this.TimeZone -ne $currentState.TimeZone)) {
            return $false
        }

        if (($null -ne $this.SetTimeZoneAutomatically) -and ($this.SetTimeZoneAutomatically -ne $currentState.SetTimeZoneAutomatically)) {
            return $false
        }

        return $true
    }

    #region Time helper functions
    static [bool] GetTimeZoneAutoUpdateStatus() {
        # key should actually always be present, but we'll check anyway
        $keyValue = TryGetRegistryValue -Key $global:tzAutoUpdatePath -Property ([TimeZone]::SetTimeZoneAutomaticallyProperty)
        if ($null -eq $keyValue) {
            return $true # if it is not present, we assume it is enabled with NTP
        } else {
            return ($keyValue -eq 1)
        }
    }

    # helper function for Pester tests
    [hashtable] ToHashTable() {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if (-not ([string]::IsNullOrEmpty($property.Value))) {
                $parameters[$property.Name] = $property.Value
            }
        }

        return $parameters
    }
    #endRegion Time helper functions
}

<#
.SYNOPSIS
    The 'Clock' DSC Resource allows you to manage the system tray date/time visibility settings on a Windows machine.

.DESCRIPTION
    The 'Clock' DSC Resource allows you to manage the system tray date/time visibility settings on a Windows machine.

.PARAMETER ShowSystemTrayDateTime
    Whether to show the date and time in the system tray. The value should be a boolean. The default value is `$true`.

.PARAMETER NotifyClockChange
    Whether to notify the user when the time changes. The value should be a boolean.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name Clock -Method Get -Property {}

    This example gets the current clock settings on the machine.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name Clock -Method Set -Property @{ ShowSystemTrayDateTime = $true; NotifyClockChange = $true }

    This example sets the system tray date/time visibility settings on the machine.
#>
[DscResource()]
class Clock {
    [DscProperty(Key)]
    [string] $SID

    [DscProperty()]
    [nullable[bool]] $ShowSystemTrayDateTime

    [DscProperty()]
    [nullable[bool]] $NotifyClockChange

    static hidden [string] $ShowSystemTrayDateTimeProperty = 'ShowSystrayDateTimeValueName'
    static hidden [string] $NtpEnabled = 'NTP'
    static hidden [string] $NtpDisabled = 'NoSync'
    static hidden [string] $NotifyClockChangeProperty = 'DstNotification'

    [Clock] Get() {
        $currentState = [Clock]::New()
        $currentState.ShowSystemTrayDateTime = [Clock]::GetShowSystemTrayDateTimeStatus()
        $currentState.NotifyClockChange = [Clock]::GetNotifyClockChangeStatus()

        return $currentState
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $currentState = $this.Get()

        if (($null -ne $this.ShowSystemTrayDateTime) -and ($currentState.ShowSystemTrayDateTime -ne $this.ShowSystemTrayDateTime)) {
            $desiredState = [int]$this.ShowSystemTrayDateTime

            if ([string]::IsNullOrEmpty((TryGetRegistryValue -Key $global:SysTrayPath -Property ([Clock]::ShowSystemTrayDateTimeProperty)))) {
                New-ItemProperty -Path $global:SysTrayPath -Name ([Clock]::ShowSystemTrayDateTimeProperty) -Value $desiredState -PropertyType DWORD
                return
            }

            Set-ItemProperty -Path $global:SysTrayPath -Name ([Clock]::ShowSystemTrayDateTimeProperty) -Value $desiredState
        }

        if (($null -ne $this.NotifyClockChange) -and ($currentState.NotifyClockChange -ne $this.NotifyClockChange)) {
            $desiredState = [int]$this.NotifyClockChange

            if ([string]::IsNullOrEmpty((TryGetRegistryValue -Key $global:AdditionalClockPath -Property ([Clock]::NotifyClockChangeProperty)))) {
                New-ItemProperty -Path $global:AdditionalClockPath -Name ([Clock]::NotifyClockChangeProperty) -Value $desiredState -PropertyType DWORD
                return
            }

            Set-ItemProperty -Path $global:AdditionalClockPath -Name ([Clock]::NotifyClockChangeProperty) -Value $desiredState
        }
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.ShowSystemTrayDateTime) -and ($this.ShowSystemTrayDateTime -ne $currentState.ShowSystemTrayDateTime)) {
            return $false
        }

        if (($null -ne $this.NotifyClockChange) -and ($this.NotifyClockChange -ne $currentState.NotifyClockChange)) {
            return $false
        }

        return $true
    }

    #region Clock helper functions
    static [bool] GetShowSystemTrayDateTimeStatus() {
        $value = TryGetRegistryValue -Key $global:SysTrayPath -Property ([Clock]::ShowSystemTrayDateTimeProperty)
        if (([string]::IsNullOrEmpty($value))) {
            # if it is empty, we assume it is set to 1
            return $true
        } else {
            return ($value -eq 1)
        }
    }

    static [bool] GetNotifyClockChangeStatus() {
        $value = TryGetRegistryValue -Key $global:AdditionalClockPath -Property ([Clock]::NotifyClockChangeProperty)
        if (([string]::IsNullOrEmpty($value))) {
            # if it is empty, we assume it is set to 1
            return $true
        } else {
            return ($value -eq 1)
        }
    }

    # helper function for Pester tests
    [hashtable] ToHashTable() {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if (-not ([string]::IsNullOrEmpty($property.Value))) {
                $parameters[$property.Name] = $property.Value
            }
        }

        return $parameters
    }
    #endRegion Clock helper functions
}
#endRegion Classes
