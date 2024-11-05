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
    [DscProperty(Key)]
    [string] $Sid 

    [DscProperty()]
    [TimeZoneAutomatically] $SetTimeZoneAutomatically = [TimeZoneAutomatically]::NTP

    [DscProperty()]
    [string] $TimeZone

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

        if ($null -ne $this.SetTimeZoneAutomatically)
        {
            Set-ItemProperty -Path $global:tzAutoUpdatePath -Name ([Time]::SetTimeZoneAutomaticallyProperty) -Value $this.SetTimeZoneAutomatically
        }

        if ($null -ne $this.TimeZone)
        {
            Set-TimeZone -Id $this.TimeZone    
        }

        if ($null -ne $this.ShowSystemTrayDateTime)
        {
            if ($this.ShowSystemTrayDateTime)
            {
                Set-ItemProperty -Path $global:SysTrayPath -Name ([Time]::ShowSystemTrayDateTimeProperty) -Value 1 # 1 = Show
            }
            else
            { 
                Set-ItemProperty -Path $global:SysTrayPath -Name ([Time]::ShowSystemTrayDateTimeProperty) -Value 0 # 0 = Hide
            }
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
            return $false
        }
        else
        {
            return ($keyValue -as [TimeZoneAutomatically])
        }        
    }

    static [bool] GetShowSystemTrayDateTimeStatus()
    {
        $value = TryGetRegistryValue -Key $global:SysTrayPath -Property ([Time]::ShowSystemTrayDateTimeProperty)
        if ($null -ne $value)
        {
            return $false
        }
        else
        {
            return ($value -eq 1)
        }        
    }
    #endRegion Time helper functions
}
#endRegion Classes