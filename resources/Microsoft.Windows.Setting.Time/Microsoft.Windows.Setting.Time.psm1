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
#endRegion Functions

#region Enums
enum TimeZoneTable {
    DatelineStandardTime
    UTC11
    AleutianStandardTime
    HawaiianStandardTime
    MarquesasStandardTime
    AlaskanStandardTime
    UTC09
    PacificStandardTimeMexico
    UTC08
    PacificStandardTime
    USMountainStandardTime
    MountainStandardTimeMexico
    MountainStandardTime
    YukonStandardTime
    CentralAmericaStandardTime
    CentralStandardTime
    EasterIslandStandardTime
    CentralStandardTimeMexico
    CanadaCentralStandardTime
    SAPacificStandardTime
    EasternStandardTimeMexico
    EasternStandardTime
    HaitiStandardTime
    CubaStandardTime
    USEasternStandardTime
    TurksAndCaicosStandardTime
    ParaguayStandardTime
    AtlanticStandardTime
    VenezuelaStandardTime
    CentralBrazilianStandardTime
    SAWesternStandardTime
    PacificSAStandardTime
    NewfoundlandStandardTime
    TocantinsStandardTime
    ESouthAmericaStandardTime
    SAEasternStandardTime
    ArgentinaStandardTime
    MontevideoStandardTime
    MagallanesStandardTime
    SaintPierreStandardTime
    BahiaStandardTime
    UTC02
    GreenlandStandardTime
    MidAtlanticStandardTime
    AzoresStandardTime
    CapeVerdeStandardTime
    UTC
    GMTStandardTime
    GreenwichStandardTime
    SaoTomeStandardTime
    MoroccoStandardTime
    WEuropeStandardTime
    CentralEuropeStandardTime
    RomanceStandardTime
    CentralEuropeanStandardTime
    WCentralAfricaStandardTime
    GTBStandardTime
    MiddleEastStandardTime
    EgyptStandardTime
    EEuropeStandardTime
    WestBankStandardTime
    SouthAfricaStandardTime
    FLEStandardTime
    IsraelStandardTime
    SouthSudanStandardTime
    KaliningradStandardTime
    SudanStandardTime
    LibyaStandardTime
    NamibiaStandardTime
    JordanStandardTime
    ArabicStandardTime
    SyriaStandardTime
    TurkeyStandardTime
    ArabStandardTime
    BelarusStandardTime
    RussianStandardTime
    EAfricaStandardTime
    VolgogradStandardTime
    IranStandardTime
    ArabianStandardTime
    AstrakhanStandardTime
    AzerbaijanStandardTime
    RussiaTimeZone3
    MauritiusStandardTime
    SaratovStandardTime
    GeorgianStandardTime
    CaucasusStandardTime
    AfghanistanStandardTime
    WestAsiaStandardTime
    QyzylordaStandardTime
    EkaterinburgStandardTime
    PakistanStandardTime
    IndiaStandardTime
    SriLankaStandardTime
    NepalStandardTime
    CentralAsiaStandardTime
    BangladeshStandardTime
    OmskStandardTime
    MyanmarStandardTime
    SEAsiaStandardTime
    AltaiStandardTime
    WMongoliaStandardTime
    NorthAsiaStandardTime
    NCentralAsiaStandardTime
    TomskStandardTime
    ChinaStandardTime
    NorthAsiaEastStandardTime
    SingaporeStandardTime
    WAustraliaStandardTime
    TaipeiStandardTime
    UlaanbaatarStandardTime
    AusCentralWStandardTime
    TransbaikalStandardTime
    TokyoStandardTime
    NorthKoreaStandardTime
    KoreaStandardTime
    YakutskStandardTime
    CenAustraliaStandardTime
    AUSCentralStandardTime
    EAustraliaStandardTime
    AUSEasternStandardTime
    WestPacificStandardTime
    TasmaniaStandardTime
    VladivostokStandardTime
    LordHoweStandardTime
    BougainvilleStandardTime
    RussiaTimeZone10
    MagadanStandardTime
    NorfolkStandardTime
    SakhalinStandardTime
    CentralPacificStandardTime
    RussiaTimeZone11
    NewZealandStandardTime
    UTC12
    FijiStandardTime
    KamchatkaStandardTime
    ChathamIslandsStandardTime
    UTC13
    TongaStandardTime
    SamoaStandardTime
    LineIslandsStandardTime

}

#endRegion Enums
function Get-ValidTimeZone {
    param (
        [Parameter()]
        # keep it string to avoid enum issues
        [string] $TimeZone = ((Get-TimeZone).Id -replace '[\+\s\-\(\)\.]', ''),

        # switch for Get() method
        [Parameter()]
        [switch] $NoValid
    )

    $list = (Get-TimeZone -ListAvailable).Id

    $trimmedVersion = $list -replace '[\+\s\-\(\)\.]', ''

    if ($trimmedVersion -contains $TimeZone) {
        if ($NoValid.IsPresent) {
            return $TimeZone
        }

        return $list[$trimmedVersion.IndexOf($TimeZone)]
    } else {
        throw 'Invalid time zone. Please provide a valid time zone without spaces and special characters.'
    }
}

#region Classes
<#
.SYNOPSIS
    DSC Resource to manage Windows Time settings.

.DESCRIPTION
    This `Time` DSC Resource allows you to manage the time zone, automatic time zone update, and system tray date/time visibility settings on a Windows machine.

.PARAMETER TimeZone
    The time zone to set on the machine. The value should be a valid time zone ID from the list of time zones (Get-TimeZone -ListAvailable).Id. The default value is the current time zone.

.PARAMETER SetTimeZoneAutomatically
    The method to use to set the time zone automatically. The value should be a boolean.

.PARAMETER ShowSystemTrayDateTime
    Whether to show the date and time in the system tray. The value should be a boolean. The default value is `$true`.

.PARAMETER NotifyClockChange
    Whether to notify the user when the time changes. The value should be a boolean.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name Time -Method Set -Property @{ TimeZone = "Pacific Standard Time"; SetTimeZoneAutomatically = "NTP"; ShowSystemTrayDateTime = $true }

    This example sets the time zone to Pacific Standard Time, sets the time zone to be updated automatically using NTP, and shows the date and time in the system tray.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name Time -Method Get -Property {}

    This example gets the current time settings on the machine.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name Time -Method Test -Property @{ TimeZone = "Pacific Standard Time"}

    This example tests whether the time zone is set to Pacific Standard Time.
#>
[DscResource()]
class Time {
    # TODO: Track issue 125 on PSDesiredStateConfiguration repository to add a ValidateSet for time zones
    [DscProperty(Key)]
    [TimeZoneTable] $TimeZone = ((Get-TimeZone).Id -replace '[\+\s\-\(\)\.]', '')

    [DscProperty()]
    [nullable[bool]] $SetTimeZoneAutomatically

    [DscProperty()]
    [nullable[bool]] $ShowSystemTrayDateTime

    [DscProperty()]
    [nullable[bool]] $NotifyClockChange

    static hidden [string] $SetTimeZoneAutomaticallyProperty = 'Type'
    static hidden [string] $ShowSystemTrayDateTimeProperty = 'ShowSystrayDateTimeValueName'
    static hidden [string] $NtpEnabled = 'NTP'
    static hidden [string] $NtpDisabled = 'NoSync'
    static hidden [string] $NotifyClockChangeProperty = 'DstNotification'

    [Time] Get() {
        $currentState = [Time]::New()
        $currentState.SetTimeZoneAutomatically = [Time]::GetTimeZoneAutoUpdateStatus()
        $currentState.TimeZone = Get-ValidTimeZone -NoValid
        $currentState.ShowSystemTrayDateTime = [Time]::GetShowSystemTrayDateTimeStatus()
        $currentState.NotifyClockChange = [Time]::GetNotifyClockChangeStatus()

        return $currentState
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        $currentState = $this.Get()

        if ($currentState.SetTimeZoneAutomatically -ne $this.SetTimeZoneAutomatically) {
            $desiredState = $this.SetTimeAutomatically ? [Time]::NtpEnabled : [Time]::NtpDisabled

            Set-ItemProperty -Path $global:tzAutoUpdatePath -Name ([Time]::SetTimeZoneAutomaticallyProperty) -Value $desiredState
        }

        if ($currentState.TimeZone -ne $this.TimeZone) {
            Set-TimeZone -Id (Get-ValidTimeZone -TimeZone $this.TimeZone)
        }

        if (($null -ne $this.ShowSystemTrayDateTime) -and ($currentState.ShowSystemTrayDateTime -ne $this.ShowSystemTrayDateTime)) {
            $desiredState = [int]$this.ShowSystemTrayDateTime

            if ([string]::IsNullOrEmpty((TryGetRegistryValue -Key $global:SysTrayPath -Property ([Time]::ShowSystemTrayDateTimeProperty)))) {
                New-ItemProperty -Path $global:SysTrayPath -Name ([Time]::ShowSystemTrayDateTimeProperty) -Value $desiredState -PropertyType DWORD
                return
            }

            Set-ItemProperty -Path $global:SysTrayPath -Name ([Time]::ShowSystemTrayDateTimeProperty) -Value $desiredState
        }

        if (($null -ne $this.NotifyClockChange) -and ($currentState.NotifyClockChange -ne $this.NotifyClockChange)) {
            $desiredState = [int]$this.NotifyClockChange

            if ([string]::IsNullOrEmpty((TryGetRegistryValue -Key $global:AdditionalClockPath -Property ([Time]::NotifyClockChangeProperty)))) {
                New-ItemProperty -Path $global:AdditionalClockPath -Name ([Time]::NotifyClockChangeProperty) -Value $desiredState -PropertyType DWORD
                return
            }

            Set-ItemProperty -Path $global:AdditionalClockPath -Name ([Time]::NotifyClockChangeProperty) -Value $desiredState
        }
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.ShowSystemTrayDateTime) -and ($this.ShowSystemTrayDateTime -ne $currentState.ShowSystemTrayDateTime)) {
            return $false
        }

        if (($null -ne $this.TimeZone) -and ($this.TimeZone -ne $currentState.TimeZone)) {
            return $false
        }

        if (($null -ne $this.SetTimeZoneAutomatically) -and ($this.SetTimeZoneAutomatically -ne $currentState.SetTimeZoneAutomatically)) {
            return $false
        }

        if (($null -ne $this.NotifyClockChange) -and ($this.NotifyClockChange -ne $currentState.NotifyClockChange)) {
            return $false
        }

        return $true
    }

    #region Time helper functions
    static [bool] GetTimeZoneAutoUpdateStatus() {
        # key should actually always be present, but we'll check anyway
        $keyValue = TryGetRegistryValue -Key $global:tzAutoUpdatePath -Property ([Time]::SetTimeZoneAutomaticallyProperty)
        if ($null -eq $keyValue) {
            return $true # if it is not present, we assume it is enabled with NTP
        } else {
            return ($keyValue -eq 1)
        }
    }

    static [bool] GetShowSystemTrayDateTimeStatus() {
        $value = TryGetRegistryValue -Key $global:SysTrayPath -Property ([Time]::ShowSystemTrayDateTimeProperty)
        if (([string]::IsNullOrEmpty($value))) {
            # if it is empty, we assume it is set to 1
            return $true
        } else {
            return ($value -eq 1)
        }
    }

    static [bool] GetNotifyClockChangeStatus() {
        $value = TryGetRegistryValue -Key $global:AdditionalClockPath -Property ([Time]::NotifyClockChangeProperty)
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
    #endRegion Time helper functions
}
#endRegion Classes
