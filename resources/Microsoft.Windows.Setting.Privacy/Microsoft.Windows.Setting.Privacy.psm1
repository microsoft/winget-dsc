if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    # $global:webcamConsentStorePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam'
    $global:advertisingInfoPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    $global:userProfilePath = 'HKCU:\Control Panel\International\User Profile'
    $global:advancedProfilePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $global:contentDeliveryManagerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $global:accountNotificationsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications'
} else {
    $global:advertisingInfoPath = $env:TestRegistryPath
}

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

    if ($itemProperty) {
        return $itemProperty.$Name
    }
}

function GetPropertyMapping {
    $inputObject = [System.Collections.Generic.List[PSCustomObject]]::new()

    $inputObject.Add([PSCustomObject]@{
            Name       = 'EnablePersonalizedAds'
            Key        = 'Enabled'
            Expression = 1
            Path       = $global:advertisingInfoPath
        })

    $inputObject.Add([PSCustomObject]@{
            Name       = 'EnableLocalContentByLanguageList'
            Key        = 'HttpAcceptLanguageOptOut'
            Expression = 0
            Path       = $global:userProfilePath
        })

    $inputObject.Add([PSCustomObject]@{
            Name       = 'EnableAppLaunchTracking'
            Key        = 'Start_TrackProgs'
            Expression = 1
            Path       = $global:advancedProfilePath
        })

    $inputObject.Add([PSCustomObject]@{
            Name       = 'ShowContentSuggestion'
            Key        = @('SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled')
            Expression = 1
            Path       = $global:contentDeliveryManagerPath
        })

    $inputObject.Add([PSCustomObject]@{
            Name       = 'EnableAccountNotifications'
            Key        = 'EnableAccountNotifications'
            Expression = 1
            Path       = $global:accountNotificationsPath
        })

    return $inputObject
}

function GetPrivacyState {
    [CmdletBinding()]
    [OutputType([Privacy])]
    param (
        [Parameter()]
        [AllowNull()]
        [hashtable] $SettableProperties
    )

    $currentState = [Privacy]::New()
    $mapping = GetPropertyMapping

    foreach ($p in $SettableProperties.GetEnumerator()) {
        $property = $mapping | Where-Object { $_.Name -eq $p.Key }
        $expression = $property.Expression
        $path = $property.Path

        if ($null -ne $property) {
            # wondering why we check for array? This is because the HttpAcceptLanguageOptOut key is buggy
            $keyValue = if ($property.Key -is [array]) {
                $property.Key | ForEach-Object { DoesRegistryKeyPropertyExist -Path $path -Name $_ }
            } else {
                DoesRegistryKeyPropertyExist -Path $path -Name $property.Key
            }

            if (-not ([string]::IsNullOrEmpty($keyValue))) {
                [bool]$setter = ($keyValue -eq $expression)

                $currentState.$($p.Key) = $setter
            } else {
                $currentState.$($p.Key) = $true
            }
        }
    }

    return $currentState
}

function TestPrivacyState {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $CurrentState,

        [Parameter(Mandatory = $true)]
        [Privacy] $TestState
    )

    $res = $true
    $CurrentState.GetEnumerator() | ForEach-Object {
        $testValue = $TestState.psobject.properties[$_.Key].Value
        if ($null -ne $testValue) {
            if ($testValue -ne $_.Value) {
                $res = $false
            }
        }
    }

    return $res
}

function SetPrivacyState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Privacy] $PrivacyState
    )

    $mapping = GetPropertyMapping

    $props = $PrivacyState.psobject.properties | Where-Object { $null -ne $_.Value }

    foreach ($p in $props) {
        $map = $mapping | Where-Object { $_.Name -eq $p.Name }
        if (-not (Test-Path $map.Path)) {
            New-Item -Path $map.Path -Force | Out-Null
        }

        foreach ($key in $map.Key) {
            $value = ($p.Value -as [int])
            if ($map.Key -eq 'HttpAcceptLanguageOptOut') {
                $value = ($value -eq 0) ? 1 : 0
            }

            if (-not (DoesRegistryKeyPropertyExist -Path $map.Path -Name $key)) {
                New-ItemProperty -Path $map.Path -Name $key -Value $value -PropertyType DWord
            }

            Set-ItemProperty -Path $map.Path -Name $key -Value $value -Force
        }
    }
}
#endregion Functions

#region Classes

[DSCResource()]
class Privacy {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string] $SID

    [DscProperty()]
    [nullable[bool]] $EnablePersonalizedAds

    [DscProperty()]
    [nullable[bool]] $EnableLocalContentByLanguageList

    [DscProperty()]
    [nullable[bool]] $EnableAppLaunchTracking

    [DscProperty()]
    [nullable[bool]] $ShowContentSuggestion

    [DscProperty()]
    [nullable[bool]] $EnableAccountNotifications

    [Privacy] Get() {
        $currentState = GetPrivacyState -SettableProperties $this.ToHashTable()
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        $result = TestPrivacyState -CurrentState $currentState.ToHashTable() -TestState $this
        return $result
    }

    [void] Set() {
        if (-not $this.Test()) {
            SetPrivacyState -PrivacyState $this
        }
    }

    #region Privacy helper functions
    static [bool] GetPersonalizedAdsStatus() {
        $keyValue = TryGetRegistryValue -Key $global:advertisingInfoPath -Property 'Enabled'
        return ($keyvalue -eq 1)
    }

    [hashtable] ToHashTable() {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties) {
            if (-not ([string]::IsNullOrEmpty($property.Value))) {
                $parameters[$property.Name] = $property.Value
            }
        }

        return $parameters
    }

    #endRegion Privacy helper functions
}
#endRegion classes
