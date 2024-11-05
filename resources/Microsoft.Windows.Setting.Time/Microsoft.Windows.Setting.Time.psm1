$global:tzAutoUpdatePath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
$global:SysTrayPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

#region Functions 
function TryGetRegistryValue
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Property
    )    

    if (Test-Path -Path $Key)
    {
        try
        {
            return (Get-ItemProperty -Path $Key -Name $Property -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Property)     
        }
        catch
        {
            Write-Verbose "Property `"$($Property)`" could not be found."
        }
    }
    else
    {
        Write-Verbose "Registry key does not exist."
    }
}
#endRegion Functions

#region Enum
enum TimeZoneAutomatically 
{
    NTP
    NoSync
}

#region Classes
[DscResource()]
class Time 
{
    # Timezone values are taken from the list of timezones (Get-TimeZone -ListAvailable).Id
    [DscProperty(Key)]
    [ValidateSet(
        "Dateline Standard Time", "UTC-11", "Aleutian Standard Time", "Hawaiian Standard Time", "Marquesas Standard Time", 
        "Alaskan Standard Time", "UTC-09", "Pacific Standard Time (Mexico)", "UTC-08", "Pacific Standard Time", 
        "US Mountain Standard Time", "Mountain Standard Time (Mexico)", "Mountain Standard Time", "Central America Standard Time", 
        "Central Standard Time", "Easter Island Standard Time", "Central Standard Time (Mexico)", "Canada Central Standard Time", 
        "SA Pacific Standard Time", "Eastern Standard Time (Mexico)", "Eastern Standard Time", "Haiti Standard Time", 
        "Cuba Standard Time", "US Eastern Standard Time", "Turks And Caicos Standard Time", "Paraguay Standard Time", 
        "Atlantic Standard Time", "Venezuela Standard Time", "Central Brazilian Standard Time", "SA Western Standard Time", 
        "Pacific SA Standard Time", "Newfoundland Standard Time", "Tocantins Standard Time", "E. South America Standard Time", 
        "SA Eastern Standard Time", "Argentina Standard Time", "Greenland Standard Time", "Montevideo Standard Time", 
        "Magallanes Standard Time", "Saint Pierre Standard Time", "Bahia Standard Time", "UTC-02", "Mid-Atlantic Standard Time", 
        "Azores Standard Time", "Cape Verde Standard Time", "UTC", "Morocco Standard Time", "GMT Standard Time", 
        "Greenwich Standard Time", "W. Europe Standard Time", "Central Europe Standard Time", "Romance Standard Time", 
        "Central European Standard Time", "W. Central Africa Standard Time", "Namibia Standard Time", "Jordan Standard Time", 
        "GTB Standard Time", "Middle East Standard Time", "Egypt Standard Time", "E. Europe Standard Time", "Syria Standard Time", 
        "West Bank Standard Time", "South Africa Standard Time", "FLE Standard Time", "Israel Standard Time", "Kaliningrad Standard Time", 
        "Sudan Standard Time", "Libya Standard Time", "Namibia Standard Time", "Arabic Standard Time", "Turkey Standard Time", 
        "Arab Standard Time", "Belarus Standard Time", "Russian Standard Time", "E. Africa Standard Time", "Iran Standard Time", 
        "Arabian Standard Time", "Astrakhan Standard Time", "Azerbaijan Standard Time", "Russia Time Zone 3", "Mauritius Standard Time", 
        "Saratov Standard Time", "Georgian Standard Time", "Caucasus Standard Time", "Afghanistan Standard Time", "West Asia Standard Time", 
        "Ekaterinburg Standard Time", "Pakistan Standard Time", "India Standard Time", "Sri Lanka Standard Time", "Nepal Standard Time", 
        "Central Asia Standard Time", "Bangladesh Standard Time", "Omsk Standard Time", "Myanmar Standard Time", "SE Asia Standard Time", 
        "Altai Standard Time", "W. Mongolia Standard Time", "North Asia Standard Time", "N. Central Asia Standard Time", 
        "Tomsk Standard Time", "China Standard Time", "North Asia East Standard Time", "Singapore Standard Time", "W. Australia Standard Time", 
        "Taipei Standard Time", "Ulaanbaatar Standard Time", "North Korea Standard Time", "Aus Central W. Standard Time", 
        "Transbaikal Standard Time", "Tokyo Standard Time", "Korea Standard Time", "Yakutsk Standard Time", "Cen. Australia Standard Time", 
        "AUS Central Standard Time", "E. Australia Standard Time", "AUS Eastern Standard Time", "West Pacific Standard Time", 
        "Tasmania Standard Time", "Vladivostok Standard Time", "Lord Howe Standard Time", "Bougainville Standard Time", 
        "Russia Time Zone 10", "Magadan Standard Time", "Norfolk Standard Time", "Sakhalin Standard Time", "Central Pacific Standard Time", 
        "Russia Time Zone 11", "New Zealand Standard Time", "UTC+12", "Fiji Standard Time", "Kamchatka Standard Time", 
        "Chatham Islands Standard Time", "UTC+13", "Tonga Standard Time", "Samoa Standard Time", "Line Islands Standard Time"
    )]
    [string] $TimeZone = (Get-TimeZone).Id

    [DscProperty()]
    [TimeZoneAutomatically] $SetTimeZoneAutomatically = [TimeZoneAutomatically]::NTP

    [DscProperty()]
    [nullable[bool]] $ShowSystemTrayDateTime

    static hidden [string] $SetTimeZoneAutomaticallyProperty = 'Type'
    static hidden [string] $ShowSystemTrayDateTimeProperty = 'ShowSystrayDateTimeValueName'

    [Time] Get()
    {
        $currentState = [Time]::New()
        $currentState.SetTimeZoneAutomatically = [Time]::GetTimeZoneAutoUpdateStatus()
        $currentState.TimeZone = (Get-TimeZone).Id
        $currentState.ShowSystemTrayDateTime = [Time]::GetShowSystemTrayDateTimeStatus()

        return $currentState
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        $currentState = $this.Get()

        if ($currentState.SetTimeZoneAutomatically -ne $this.SetTimeZoneAutomatically)
        {
            Set-ItemProperty -Path $global:tzAutoUpdatePath -Name ([Time]::SetTimeZoneAutomaticallyProperty) -Value $this.SetTimeZoneAutomatically
        }

        if ($currentState.TimeZone -ne $this.TimeZone)
        {
            Set-TimeZone -Id $this.TimeZone    
        }

        if ($currentState.ShowSystemTrayDateTime -ne $this.ShowSystemTrayDateTime)
        {
            $desiredState = switch ($this.ShowSystemTrayDateTime)
            {
                $true { "1" } # 1 = Show
                $false { "0" } # 0 = Hide
            }

            if ([string]::IsNullOrEmpty((TryGetRegistryValue -Key $global:SysTrayPath -Property ([Time]::ShowSystemTrayDateTimeProperty))))
            {
                New-ItemProperty -Path $global:SysTrayPath -Name ([Time]::ShowSystemTrayDateTimeProperty) -Value $desiredState -PropertyType DWORD
                return
            }

            Set-ItemProperty -Path $global:SysTrayPath -Name ([Time]::ShowSystemTrayDateTimeProperty) -Value $desiredState
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()

        if (($null -ne $this.ShowSystemTrayDateTime) -and ($this.ShowSystemTrayDateTime -ne $currentState.ShowSystemTrayDateTime))
        {
            return $false
        }

        if (($null -ne $this.TimeZone) -and ($this.TimeZone -ne $currentState.TimeZone))
        {
            return $false
        }

        if (($null -ne $this.SetTimeZoneAutomatically) -and ($this.SetTimeZoneAutomatically -ne $currentState.SetTimeZoneAutomatically))
        {
            return $false
        }

        return $true
    }

    #region Time helper functions
    static [TimeZoneAutomatically] GetTimeZoneAutoUpdateStatus()
    {
        # key should actually always be present, but we'll check anyway
        $keyValue = TryGetRegistryValue -Key $global:tzAutoUpdatePath -Property ([Time]::SetTimeZoneAutomaticallyProperty)
        if ($null -eq $keyValue)
        {
            return [TimeZoneAutomatically]::NTP
        }
        else
        {
            return ($keyValue -as [TimeZoneAutomatically])
        }        
    }

    static [bool] GetShowSystemTrayDateTimeStatus()
    {
        $value = TryGetRegistryValue -Key $global:SysTrayPath -Property ([Time]::ShowSystemTrayDateTimeProperty)
        if (([string]::IsNullOrEmpty($value)) -or ($null -eq $value))
        {
            # if it is empty, we assume it is set to 1
            return $true
        }
        else
        {
            return ($value -eq 1)
        }        
    }
    #endRegion Time helper functions
}
#endRegion Classes