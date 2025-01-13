if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:ExplorerPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $global:CdpPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP\'
    $global:ArchiveAppPath = ('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\InstallService\Stubification\{0}\' -f ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value)
    $global:AppPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\'

} else {
    $global:ExplorerPath = $env:TestRegistryPath
}

#region Load required assemblies
$library = @(Get-ChildItem -Path "$PSScriptRoot\lib\*.dll" -Recurse -ErrorAction SilentlyContinue)
$assembly = [System.AppDomain]::CurrentDomain.GetAssemblies()

foreach ($type in $library) {
    $typeName = $type.BaseName
    $assemblyType = $assembly | Where-Object { $_.GetName().Name -eq $typeName }
    if ($null -eq $assemblyType) {
        Add-Type -Path $type.FullName
    }
}
#endregion Load required assemblies

#region Enums
enum AppSourcePreference {
    Anywhere
    Recommendations
    PreferStore
    StoreOnly
}

enum ShareDeviceExperience {
    Off
    Device
    Everyone
}
#endregion Enums

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

function Set-AdvancedAppSettings {
    param (
        [AppSourcePreference] $AppSourcePreference,
        [ShareDeviceExperience] $ShareDeviceExperience,
        [nullable[bool]] $ArchiveApp
    )

    if ($null -ne $AppSourcePreference) {
        if (-not (DoesRegistryKeyPropertyExist -Path $global:ExplorerPath -Name ([AdvancedAppSettings]::AppSourcePreferenceProperty))) {
            New-ItemProperty -Path $global:ExplorerPath -Name ([AdvancedAppSettings]::AppSourcePreferenceProperty) -Value $appSourcePreference -PropertyType String | Out-Null
        }
        Set-ItemProperty -Path $global:ExplorerPath -Name ([AdvancedAppSettings]::AppSourcePreferenceProperty) -Value $appSourcePreference
    }

    if ($null -ne $ShareDeviceExperience) {
        $shareDeviceExperienceValue = switch ($ShareDeviceExperience) {
            'Off' { 0 }
            'Device' { 1 }
            'Everyone' { 2 }
            default { 0 }
        }

        if (-not (DoesRegistryKeyPropertyExist -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1))) {
            New-ItemProperty -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1) -Value $shareDeviceExperienceValue -PropertyType DWord | Out-Null
        }

        if (-not (DoesRegistryKeyPropertyExist -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty2))) {
            New-ItemProperty -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty2) -Value $shareDeviceExperienceValue -PropertyType DWord | Out-Null
        }
        Set-ItemProperty -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1) -Value $shareDeviceExperienceValue
        Set-ItemProperty -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty2) -Value $shareDeviceExperienceValue
    }

    if ($null -ne $ArchiveApp) {
        if (-not (Test-Path -Path $global:ArchiveAppPath -ErrorAction SilentlyContinue)) {
            New-Item -Path $global:ArchiveAppPath -Force
        }

        if (-not (DoesRegistryKeyPropertyExist -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty))) {
            New-ItemProperty -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty) -Value ([int]$ArchiveApp) -PropertyType DWord | Out-Null
        }
        Set-ItemProperty -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty) -Value ([int]$ArchiveApp)
    }
}

function Resolve-AppXExePath {
    param(
        [Parameter(ValueFromPipeline)]
        [Alias('PSPath')]
        [string] $LiteralPath
    )

    process {
        $fullName = Convert-Path -LiteralPath $LiteralPath
        if (-not $?) { return }

        $hexDump = fsutil reparsepoint query $fullName 2>&1
        if ($LASTEXITCODE) { Throw $hexDump }

        [byte[]] $bytes = -split ( -join ($hexDump -match '^[a-f0-9]+:' -replace '^[a-f0-9]+:\s+(((?:[a-f0-9]{2}) +){1,16}).+$', '$1')) -replace '^', '0x'

        $props = [System.Text.Encoding]::Unicode.GetString($bytes) -split "`0"

        [PSCustomObject] @{
            AppId  = $props[2]
            Target = $props[3]
        }
    }
}

function Set-AppExecutionAlias {
    param (
        [Parameter(Mandatory)]
        [string]$ExecutionAliasName,

        [Parameter(Mandatory)]
        [bool]$Exist
    )

    $windowsAppsPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    $aliasPath = Get-ChildItem -Path $windowsAppsPath -Recurse | Where-Object { $_.Name -eq $ExecutionAliasName } | Select-Object -First 1

    if ($Exist) {
        if ($aliasPath) {
            $resolvedPath = Resolve-AppXExePath -LiteralPath $aliasPath.FullName
            $appPath = "$global:AppPath\$ExecutionAliasName"

            if (-not (Test-Path -Path $appPath)) {
                New-Item -Path $appPath -Force | Out-Null
            }

            if (-not (DoesRegistryKeyPropertyExist -Path $appPath -Name '(Default)')) {
                New-ItemProperty -Path $appPath -Name '(Default)' -Value $resolvedPath.Target -PropertyType String | Out-Null
            }
            Set-ItemProperty -Path $appPath -Name '(Default)' -Value $resolvedPath.Target

            $Parent = Split-Path -Path $resolvedPath.Target -Parent
            if (-not (DoesRegistryKeyPropertyExist -Path $appPath -Name 'Path')) {
                New-ItemProperty -Path $appPath -Name 'Path' -Value $Parent -PropertyType String | Out-Null
            }
            Set-ItemProperty -Path $appPath -Name 'Path' -Value "$Parent\"
        } else {
            Throw "Executable $ExecutionAliasName not found in $windowsAppsPath. Please install the application installer."
        }
    } else {
        $appPath = "$global:AppPath\$ExecutionAliasName"
        # Additional check to ensure that the path exists before attempting to remove it.
        if (Test-Path -Path $appPath) {
            Remove-Item -Path $appPath -Force
        }
    }
}

function Get-GeoLocationCoordinate {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Address,

        # Return address keys to support testing scenarios.
        [Parameter()]
        [switch] $ReturnAddress
    )

    $geoData = @{
        #region Africa
        'Algeria'                       = @{
            'Latitude'  = 28.0339
            'Longitude' = 1.6596
            'Altitude'  = 0
        }
        'Angola'                        = @{
            'Latitude'  = -11.2027
            'Longitude' = 17.8739
            'Altitude'  = 0
        }
        'Benin'                         = @{
            'Latitude'  = 9.3077
            'Longitude' = 2.3158
            'Altitude'  = 0
        }
        'Botswana'                      = @{
            'Latitude'  = -22.3285
            'Longitude' = 24.6849
            'Altitude'  = 0
        }
        'Burkina Faso'                  = @{
            'Latitude'  = 12.2383
            'Longitude' = -1.5616
            'Altitude'  = 0
        }
        'Burundi'                       = @{
            'Latitude'  = -3.3731
            'Longitude' = 29.9189
            'Altitude'  = 0
        }
        'Cameroon'                      = @{
            'Latitude'  = 7.3697
            'Longitude' = 12.3547
            'Altitude'  = 0
        }
        'Cape Verde'                    = @{
            'Latitude'  = 16.5388
            'Longitude' = -23.0418
            'Altitude'  = 0
        }
        'Central African Republic'      = @{
            'Latitude'  = 6.6111
            'Longitude' = 20.9394
            'Altitude'  = 0
        }
        'Chad'                          = @{
            'Latitude'  = 15.4542
            'Longitude' = 18.7322
            'Altitude'  = 0
        }
        'Comoros'                       = @{
            'Latitude'  = -11.6455
            'Longitude' = 43.3333
            'Altitude'  = 0
        }
        'Congo'                         = @{
            'Latitude'  = -0.2280
            'Longitude' = 15.8277
            'Altitude'  = 0
        }
        'Djibouti'                      = @{
            'Latitude'  = 11.8251
            'Longitude' = 42.5903
            'Altitude'  = 0
        }
        'Egypt'                         = @{
            'Latitude'  = 26.8206
            'Longitude' = 30.8025
            'Altitude'  = 0
        }
        'Equatorial Guinea'             = @{
            'Latitude'  = 1.6508
            'Longitude' = 10.2679
            'Altitude'  = 0
        }
        'Eritrea'                       = @{
            'Latitude'  = 15.1794
            'Longitude' = 39.7823
            'Altitude'  = 0
        }
        'Ethiopia'                      = @{
            'Latitude'  = 9.1450
            'Longitude' = 40.4897
            'Altitude'  = 0
        }
        'Gabon'                         = @{
            'Latitude'  = -0.8037
            'Longitude' = 11.6094
            'Altitude'  = 0
        }
        'Gambia'                        = @{
            'Latitude'  = 13.4432
            'Longitude' = -15.3101
            'Altitude'  = 0
        }
        'Ghana'                         = @{
            'Latitude'  = 7.9465
            'Longitude' = -1.0232
            'Altitude'  = 0
        }
        'Guinea'                        = @{
            'Latitude'  = 9.9456
            'Longitude' = -9.6966
            'Altitude'  = 0
        }
        'Guinea-Bissau'                 = @{
            'Latitude'  = 11.8037
            'Longitude' = -15.1804
            'Altitude'  = 0
        }
        'Ivory Coast'                   = @{
            'Latitude'  = 7.5400
            'Longitude' = -5.5471
            'Altitude'  = 0
        }
        'Kenya'                         = @{
            'Latitude'  = -1.2921
            'Longitude' = 36.8219
            'Altitude'  = 0
        }
        'Lesotho'                       = @{
            'Latitude'  = -29.609988
            'Longitude' = 28.233608
            'Altitude'  = 0
        }
        'Liberia'                       = @{
            'Latitude'  = 6.4281
            'Longitude' = -9.4295
            'Altitude'  = 0
        }
        'Libya'                         = @{
            'Latitude'  = 26.3351
            'Longitude' = 17.2283
            'Altitude'  = 0
        }
        'Madagascar'                    = @{
            'Latitude'  = -18.7669
            'Longitude' = 46.8691
            'Altitude'  = 0
        }
        'Malawi'                        = @{
            'Latitude'  = -13.2543
            'Longitude' = 34.3015
            'Altitude'  = 0
        }
        'Mali'                          = @{
            'Latitude'  = 17.5707
            'Longitude' = -3.9962
            'Altitude'  = 0
        }
        'Mauritania'                    = @{
            'Latitude'  = 21.0079
            'Longitude' = 10.9408
            'Altitude'  = 0
        }
        'Mauritius'                     = @{
            'Latitude'  = -20.3484
            'Longitude' = 57.5522
            'Altitude'  = 0
        }
        'Morocco'                       = @{
            'Latitude'  = 31.7917
            'Longitude' = -7.0926
            'Altitude'  = 0
        }
        'Mozambique'                    = @{
            'Latitude'  = -18.6657
            'Longitude' = 35.5296
            'Altitude'  = 0
        }
        'Namibia'                       = @{
            'Latitude'  = -22.9576
            'Longitude' = 18.4904
            'Altitude'  = 0
        }
        'Niger'                         = @{
            'Latitude'  = 17.6078
            'Longitude' = 8.0817
            'Altitude'  = 0
        }
        'Nigeria'                       = @{
            'Latitude'  = 9.0820
            'Longitude' = 8.6753
            'Altitude'  = 0
        }
        'Rwanda'                        = @{
            'Latitude'  = -1.9403
            'Longitude' = 29.8739
            'Altitude'  = 0
        }
        'Siant Helena'                  = @{
            'Latitude'  = -24.1435
            'Longitude' = -10.0307
            'Altitude'  = 0
        }
        'Soa Tome and Principe'         = @{
            'Latitude'  = 0.1864
            'Longitude' = 6.6131
            'Altitude'  = 0
        }
        'Senegal'                       = @{
            'Latitude'  = 14.4974
            'Longitude' = -14.4524
            'Altitude'  = 0
        }
        'Seychelles'                    = @{
            'Latitude'  = -4.6796
            'Longitude' = 55.4919
            'Altitude'  = 0
        }
        'Sierra Leone'                  = @{
            'Latitude'  = 8.4606
            'Longitude' = -11.7799
            'Altitude'  = 0
        }
        'Somalia'                       = @{
            'Latitude'  = 5.1521
            'Longitude' = 46.1996
            'Altitude'  = 0
        }
        'South Africa'                  = @{
            'Latitude'  = -30.5595
            'Longitude' = 22.9375
            'Altitude'  = 0
        }
        'Swaziland'                     = @{
            'Latitude'  = -26.5225
            'Longitude' = 31.4659
            'Altitude'  = 0
        }
        'Tanzania'                      = @{
            'Latitude'  = -6.3690
            'Longitude' = 34.8888
            'Altitude'  = 0
        }
        'Togo'                          = @{
            'Latitude'  = 8.6195
            'Longitude' = 0.8248
            'Altitude'  = 0
        }
        'Tunisia'                       = @{
            'Latitude'  = 33.8869
            'Longitude' = 9.5375
            'Altitude'  = 0
        }
        'Uganda'                        = @{
            'Latitude'  = 1.3733
            'Longitude' = 32.2903
            'Altitude'  = 0
        }
        'Zambia'                        = @{
            'Latitude'  = -13.1339
            'Longitude' = 27.8493
            'Altitude'  = 0
        }
        'Zimbabwe'                      = @{
            'Latitude'  = -19.0154
            'Longitude' = 29.1549
            'Altitude'  = 0
        }
        #endregion Africa
        #region Asia
        'Azarbaijan'                    = @{
            'Latitude'  = 40.1431
            'Longitude' = 47.5769
            'Altitude'  = 0
        }
        'Bahrain'                       = @{
            'Latitude'  = 26.0667
            'Longitude' = 50.5577
            'Altitude'  = 0
        }
        'Bangladesh'                    = @{
            'Latitude'  = 23.6850
            'Longitude' = 90.3563
            'Altitude'  = 0
        }
        'Brunei'                        = @{
            'Latitude'  = 4.5353
            'Longitude' = 114.7277
            'Altitude'  = 0
        }
        'Hong kong and Macau'           = @{
            'Latitude'  = 22.3193
            'Longitude' = 114.1694
            'Altitude'  = 0
        }
        'Andrhra Pradesh'               = @{
            'Latitude'  = 15.9129
            'Longitude' = 79.7400
            'Altitude'  = 0
        }
        'Bihar/Jharkhand'               = @{
            'Latitude'  = 25.0961
            'Longitude' = 85.3131
            'Altitude'  = 0
        }
        'Delhi'                         = @{
            'Latitude'  = 28.7041
            'Longitude' = 77.1025
            'Altitude'  = 0
        }
        'Gujarat & DD/DN'               = @{
            'Latitude'  = 22.2587
            'Longitude' = 71.1924
            'Altitude'  = 0
        }
        'Haryana/Delhi'                 = @{
            'Latitude'  = 29.0588
            'Longitude' = 76.0856
            'Altitude'  = 0
        }
        'Himachal Pradesh'              = @{
            'Latitude'  = 31.1048
            'Longitude' = 77.1734
            'Altitude'  = 0
        }
        'Jammu and Kashmir'             = @{
            'Latitude'  = 33.7782
            'Longitude' = 76.5762
            'Altitude'  = 0
        }
        'Karnataka/Goa'                 = @{
            'Latitude'  = 15.3173
            'Longitude' = 75.7139
            'Altitude'  = 0
        }
        'Kerala'                        = @{
            'Latitude'  = 10.8505
            'Longitude' = 76.2711
            'Altitude'  = 0
        }
        'Madhya Pradesh'                = @{
            'Latitude'  = 22.9734
            'Longitude' = 78.6569
            'Altitude'  = 0
        }
        'Maharashtra'                   = @{
            'Latitude'  = 19.7515
            'Longitude' = 75.7139
            'Altitude'  = 0
        }
        'North East'                    = @{
            'Latitude'  = 26.2006
            'Longitude' = 92.9376
            'Altitude'  = 0
        }
        'Orissa'                        = @{
            'Latitude'  = 20.9517
            'Longitude' = 85.0985
            'Altitude'  = 0
        }
        'Punjab'                        = @{
            'Latitude'  = 31.1471
            'Longitude' = 75.3412
            'Altitude'  = 0
        }
        'Rajasthan'                     = @{
            'Latitude'  = 27.0238
            'Longitude' = 74.2179
            'Altitude'  = 0
        }
        'Tamil Nadu'                    = @{
            'Latitude'  = 11.1271
            'Longitude' = 78.6569
            'Altitude'  = 0
        }
        'Telangana'                     = @{
            'Latitude'  = 18.1124
            'Longitude' = 79.0193
            'Altitude'  = 0
        }
        'Uttar Pradesh'                 = @{
            'Latitude'  = 26.8467
            'Longitude' = 80.9462
            'Altitude'  = 0
        }
        'West Bengal'                   = @{
            'Latitude'  = 22.9868
            'Longitude' = 87.8550
            'Altitude'  = 0
        }
        'Indonesia'                     = @{
            'Latitude'  = -0.7893
            'Longitude' = 113.9213
            'Altitude'  = 0
        }
        'Iran'                          = @{
            'Latitude'  = 32.4279
            'Longitude' = 53.6880
            'Altitude'  = 0
        }
        'Iraq'                          = @{
            'Latitude'  = 33.2232
            'Longitude' = 43.6793
            'Altitude'  = 0
        }
        'Israel'                        = @{
            'Latitude'  = 31.0461
            'Longitude' = 34.8516
            'Altitude'  = 0
        }
        'Jordan'                        = @{
            'Latitude'  = 30.5852
            'Longitude' = 36.2384
            'Altitude'  = 0
        }
        'Kazakhstan'                    = @{
            'Latitude'  = 48.0196
            'Longitude' = 66.9237
            'Altitude'  = 0
        }
        'Kuwait'                        = @{
            'Latitude'  = 29.3117
            'Longitude' = 47.4818
            'Altitude'  = 0
        }
        'Lebanon'                       = @{
            'Latitude'  = 33.8547
            'Longitude' = 35.8623
            'Altitude'  = 0
        }
        'Malaysia'                      = @{
            'Latitude'  = 4.2105
            'Longitude' = 101.9758
            'Altitude'  = 0
        }
        'Maldives'                      = @{
            'Latitude'  = 3.2028
            'Longitude' = 73.2207
            'Altitude'  = 0
        }
        'Nepal'                         = @{
            'Latitude'  = 28.3949
            'Longitude' = 84.1240
            'Altitude'  = 0
        }
        'Oman'                          = @{
            'Latitude'  = 21.4735
            'Longitude' = 55.9754
            'Altitude'  = 0
        }
        'Philippines'                   = @{
            'Latitude'  = 12.8797
            'Longitude' = 121.7740
            'Altitude'  = 0
        }
        'Qatar'                         = @{
            'Latitude'  = 25.3548
            'Longitude' = 51.1839
            'Altitude'  = 0
        }
        'Saudi Arabia'                  = @{
            'Latitude'  = 23.8859
            'Longitude' = 45.0792
            'Altitude'  = 0
        }
        'Singapore'                     = @{
            'Latitude'  = 1.3521
            'Longitude' = 103.8198
            'Altitude'  = 0
        }
        'Sri Lanka'                     = @{
            'Latitude'  = 7.8731
            'Longitude' = 80.7718
            'Altitude'  = 0
        }
        'Taiwan'                        = @{
            'Latitude'  = 23.6978
            'Longitude' = 120.9605
            'Altitude'  = 0
        }
        'Thailand'                      = @{
            'Latitude'  = 15.8700
            'Longitude' = 100.9925
            'Altitude'  = 0
        }
        'United Arab Emirates'          = @{
            'Latitude'  = 23.4241
            'Longitude' = 53.8478
            'Altitude'  = 0
        }
        'Vietnam'                       = @{
            'Latitude'  = 14.0583
            'Longitude' = 108.2772
            'Altitude'  = 0
        }
        'Yemen'                         = @{
            'Latitude'  = 15.5527
            'Longitude' = 48.5164
            'Altitude'  = 0
        }
        #endregion Asia
        #region Austrialia
        'Fiji'                          = @{
            'Latitude'  = -17.7134
            'Longitude' = 178.0650
            'Altitude'  = 0
        }
        'New Zealand'                   = @{
            'Latitude'  = -40.9006
            'Longitude' = 174.8860
            'Altitude'  = 0
        }
        #endregion Austrialia
        #region Europe
        'Albania'                       = @{
            'Latitude'  = 41.1533
            'Longitude' = 20.1683
            'Altitude'  = 0
        }
        'Andorra'                       = @{
            'Latitude'  = 42.5063
            'Longitude' = 1.5218
            'Altitude'  = 0
        }
        'Austria'                       = @{
            'Latitude'  = 47.5162
            'Longitude' = 14.5501
            'Altitude'  = 0
        }
        'Belarus'                       = @{
            'Latitude'  = 53.7098
            'Longitude' = 27.9534
            'Altitude'  = 0
        }
        'Belgium'                       = @{
            'Latitude'  = 50.5039
            'Longitude' = 4.4699
            'Altitude'  = 0
        }
        'Bosnia and Herzegovina'        = @{
            'Latitude'  = 43.9159
            'Longitude' = 17.6791
            'Altitude'  = 0
        }
        'Bulgaria'                      = @{
            'Latitude'  = 42.7339
            'Longitude' = 25.4858
            'Altitude'  = 0
        }
        'Croatia'                       = @{
            'Latitude'  = 45.1000
            'Longitude' = 15.2000
            'Altitude'  = 0
        }
        'Cyprus'                        = @{
            'Latitude'  = 35.1264
            'Longitude' = 33.4299
            'Altitude'  = 0
        }
        'Czech Republic'                = @{
            'Latitude'  = 49.8175
            'Longitude' = 15.4730
            'Altitude'  = 0
        }
        'Denmark'                       = @{
            'Latitude'  = 56.2639
            'Longitude' = 9.5018
            'Altitude'  = 0
        }
        'Estonia'                       = @{
            'Latitude'  = 58.5953
            'Longitude' = 25.0136
            'Altitude'  = 0
        }
        'Finland'                       = @{
            'Latitude'  = 61.9241
            'Longitude' = 25.7482
            'Altitude'  = 0
        }
        'Alsace'                        = @{
            'Latitude'  = 48.3182
            'Longitude' = 7.4416
            'Altitude'  = 0
        }
        'Aquitaine'                     = @{
            'Latitude'  = 44.7000
            'Longitude' = 0.0000
            'Altitude'  = 0
        }
        'Auvergne'                      = @{
            'Latitude'  = 45.7000
            'Longitude' = 3.2500
            'Altitude'  = 0
        }
        'Brittany'                      = @{
            'Latitude'  = 48.0000
            'Longitude' = -3.0000
            'Altitude'  = 0
        }
        'Burgundy'                      = @{
            'Latitude'  = 47.0000
            'Longitude' = 4.5000
            'Altitude'  = 0
        }
        'Center'                        = @{
            'Latitude'  = 47.0000
            'Longitude' = 1.7000
            'Altitude'  = 0
        }
        'Champagne-Ardenne'             = @{
            'Latitude'  = 49.0000
            'Longitude' = 4.5000
            'Altitude'  = 0
        }
        'Corsica'                       = @{
            'Latitude'  = 42.0000
            'Longitude' = 9.0000
            'Altitude'  = 0
        }
        'Franche-Comte'                 = @{
            'Latitude'  = 47.0000
            'Longitude' = 6.0000
            'Altitude'  = 0
        }
        'French Guiana'                 = @{
            'Latitude'  = 4.0000
            'Longitude' = -53.0000
            'Altitude'  = 0
        }
        'Guadeloupe'                    = @{
            'Latitude'  = 16.2500
            'Longitude' = -61.5833
            'Altitude'  = 0
        }
        'Langudoc-Roussillon'           = @{
            'Latitude'  = 43.0000
            'Longitude' = 3.0000
            'Altitude'  = 0
        }
        'Limousin'                      = @{
            'Latitude'  = 45.5000
            'Longitude' = 1.2500
            'Altitude'  = 0
        }
        'Lorraine'                      = @{
            'Latitude'  = 49.0000
            'Longitude' = 6.0000
            'Altitude'  = 0
        }
        'Martinique'                    = @{
            'Latitude'  = 14.6667
            'Longitude' = -61.0000
            'Altitude'  = 0
        }
        'Midi-Pyrenees'                 = @{
            'Latitude'  = 43.0000
            'Longitude' = 1.0000
            'Altitude'  = 0
        }
        'Nord-Pas-de-Calais'            = @{
            'Latitude'  = 50.5000
            'Longitude' = 3.0000
            'Altitude'  = 0
        }
        'Normandy'                      = @{
            'Latitude'  = 49.0000
            'Longitude' = 0.0000
            'Altitude'  = 0
        }
        'Paris-Isle-of-France'          = @{
            'Latitude'  = 48.0000
            'Longitude' = 2.0000
            'Altitude'  = 0
        }
        'Pays de la Loire'              = @{
            'Latitude'  = 47.5000
            'Longitude' = -0.5000
            'Altitude'  = 0
        }
        'Poitou-Charentes'              = @{
            'Latitude'  = 46.0000
            'Longitude' = -0.5000
            'Altitude'  = 0
        }
        'Provence-Alpes-Azur'           = @{
            'Latitude'  = 43.0000
            'Longitude' = 6.0000
            'Altitude'  = 0
        }
        'Reunion'                       = @{
            'Latitude'  = -21.1151
            'Longitude' = 55.5364
            'Altitude'  = 0
        }
        'Rhone-Alpes'                   = @{
            'Latitude'  = 45.0000
            'Longitude' = 5.0000
            'Altitude'  = 0
        }
        'Saint Barthelemy'              = @{
            'Latitude'  = 17.9000
            'Longitude' = -62.8333
            'Altitude'  = 0
        }
        'Georgia'                       = @{
            'Latitude'  = 42.3154
            'Longitude' = 43.3569
            'Altitude'  = 0
        }
        'Germany'                       = @{
            'Latitude'  = 51.1657
            'Longitude' = 10.4515
            'Altitude'  = 0
        }
        'Gibraltar'                     = @{
            'Latitude'  = 36.1408
            'Longitude' = -5.3536
            'Altitude'  = 0
        }
        'Greece'                        = @{
            'Latitude'  = 39.0742
            'Longitude' = 21.8243
            'Altitude'  = 0
        }
        'Hungary'                       = @{
            'Latitude'  = 47.1625
            'Longitude' = 19.5033
            'Altitude'  = 0
        }
        'Iceland'                       = @{
            'Latitude'  = 64.9631
            'Longitude' = -19.0208
            'Altitude'  = 0
        }
        'Ireland'                       = @{
            'Latitude'  = 53.4129
            'Longitude' = -8.2439
            'Altitude'  = 0
        }
        'Italy'                         = @{
            'Latitude'  = 41.8719
            'Longitude' = 12.5674
            'Altitude'  = 0
        }
        'Abruzzo'                       = @{
            'Latitude'  = 42.2000
            'Longitude' = 13.8333
            'Altitude'  = 0
        }
        'Basilicata'                    = @{
            'Latitude'  = 40.0000
            'Longitude' = 16.5000
            'Altitude'  = 0
        }
        'Calabria'                      = @{
            'Latitude'  = 39.0000
            'Longitude' = 16.5000
            'Altitude'  = 0
        }
        'Campania'                      = @{
            'Latitude'  = 40.8333
            'Longitude' = 14.2500
            'Altitude'  = 0
        }
        'Emilia-Romagna'                = @{
            'Latitude'  = 44.5000
            'Longitude' = 11.3333
            'Altitude'  = 0
        }
        'Friuli-Venezia Giulia'         = @{
            'Latitude'  = 46.0000
            'Longitude' = 13.0000
            'Altitude'  = 0
        }
        'Lazio'                         = @{
            'Latitude'  = 42.0000
            'Longitude' = 12.5000
            'Altitude'  = 0
        }
        'Liguria'                       = @{
            'Latitude'  = 44.0000
            'Longitude' = 8.0000
            'Altitude'  = 0
        }
        'Lombardy'                      = @{
            'Latitude'  = 45.5000
            'Longitude' = 9.5000
            'Altitude'  = 0
        }
        'Marche'                        = @{
            'Latitude'  = 43.5000
            'Longitude' = 13.5000
            'Altitude'  = 0
        }
        'Molise'                        = @{
            'Latitude'  = 41.6667
            'Longitude' = 14.6667
            'Altitude'  = 0
        }
        'Piemonte'                      = @{
            'Latitude'  = 45.0000
            'Longitude' = 7.6667
            'Altitude'  = 0
        }
        'Puglia'                        = @{
            'Latitude'  = 41.0000
            'Longitude' = 16.0000
            'Altitude'  = 0
        }
        'Sardegna'                      = @{
            'Latitude'  = 40.0000
            'Longitude' = 9.0000
            'Altitude'  = 0
        }
        'Sicilia'                       = @{
            'Latitude'  = 37.5000
            'Longitude' = 14.0000
            'Altitude'  = 0
        }
        'Toscana'                       = @{
            'Latitude'  = 43.0000
            'Longitude' = 11.0000
            'Altitude'  = 0
        }
        'Trentino-Alto Adige'           = @{
            'Latitude'  = 46.0000
            'Longitude' = 11.0000
            'Altitude'  = 0
        }
        'Umbria'                        = @{
            'Latitude'  = 42.8333
            'Longitude' = 12.8333
            'Altitude'  = 0
        }
        "Valle d'Aosta"                 = @{
            'Latitude'  = 45.7500
            'Longitude' = 7.5000
            'Altitude'  = 0
        }
        'Veneto'                        = @{
            'Latitude'  = 45.5000
            'Longitude' = 12.0000
            'Altitude'  = 0
        }
        'Latvia'                        = @{
            'Latitude'  = 56.8796
            'Longitude' = 24.6032
            'Altitude'  = 0
        }
        'Liechtenstein'                 = @{
            'Latitude'  = 47.1660
            'Longitude' = 9.5554
            'Altitude'  = 0
        }
        'Lithuania'                     = @{
            'Latitude'  = 55.1694
            'Longitude' = 23.8813
            'Altitude'  = 0
        }
        'Luxembourg'                    = @{
            'Latitude'  = 49.8153
            'Longitude' = 6.1296
            'Altitude'  = 0
        }
        'Malta'                         = @{
            'Latitude'  = 35.9375
            'Longitude' = 14.3754
            'Altitude'  = 0
        }
        'Moldova'                       = @{
            'Latitude'  = 47.4116
            'Longitude' = 28.3699
            'Altitude'  = 0
        }
        'Monaco'                        = @{
            'Latitude'  = 43.7384
            'Longitude' = 7.4246
            'Altitude'  = 0
        }
        'Montenegro'                    = @{
            'Latitude'  = 42.7087
            'Longitude' = 19.3744
            'Altitude'  = 0
        }
        'Netherlands'                   = @{
            'Latitude'  = 52.1326
            'Longitude' = 5.2913
            'Altitude'  = 0
        }
        'North Macedonia'               = @{
            'Latitude'  = 41.6086
            'Longitude' = 21.7453
            'Altitude'  = 0
        }
        'Norway'                        = @{
            'Latitude'  = 60.4720
            'Longitude' = 8.4689
            'Altitude'  = 0
        }
        'Poland'                        = @{
            'Latitude'  = 51.9194
            'Longitude' = 19.1451
            'Altitude'  = 0
        }
        'Portugal'                      = @{
            'Latitude'  = 39.3999
            'Longitude' = -8.2245
            'Altitude'  = 0
        }
        'Romania'                       = @{
            'Latitude'  = 45.9432
            'Longitude' = 24.9668
            'Altitude'  = 0
        }
        'Central Federal District'      = @{
            'Latitude'  = 55.7558
            'Longitude' = 37.6176
            'Altitude'  = 0
        }
        'Far Eastern Federal District'  = @{
            'Latitude'  = 48.7194
            'Longitude' = 134.5433
            'Altitude'  = 0
        }
        'Northwestern Federal District' = @{
            'Latitude'  = 59.9390
            'Longitude' = 30.3158
            'Altitude'  = 0
        }
        'Siberian Federal District'     = @{
            'Latitude'  = 55.1694
            'Longitude' = 82.9061
            'Altitude'  = 0
        }
        'Southern Federal District'     = @{
            'Latitude'  = 45.0356
            'Longitude' = 38.9750
            'Altitude'  = 0
        }
        'Urals Federal District'        = @{
            'Latitude'  = 56.8389
            'Longitude' = 60.6057
            'Altitude'  = 0
        }
        'Volga Federal District'        = @{
            'Latitude'  = 55.7558
            'Longitude' = 48.7448
            'Altitude'  = 0
        }
        'San Marino'                    = @{
            'Latitude'  = 43.9424
            'Longitude' = 12.4578
            'Altitude'  = 0
        }
        'Serbia'                        = @{
            'Latitude'  = 44.0165
            'Longitude' = 21.0059
            'Altitude'  = 0
        }
        'Slovakia'                      = @{
            'Latitude'  = 48.6690
            'Longitude' = 19.6990
            'Altitude'  = 0
        }
        'Slovenia'                      = @{
            'Latitude'  = 46.1512
            'Longitude' = 14.9955
            'Altitude'  = 0
        }
        'Andalucia'                     = @{
            'Latitude'  = 37.5443
            'Longitude' = -4.7278
            'Altitude'  = 0
        }
        'Aragon'                        = @{
            'Latitude'  = 41.5976
            'Longitude' = -0.9057
            'Altitude'  = 0
        }
        'Asturias'                      = @{
            'Latitude'  = 43.3614
            'Longitude' = -5.8593
            'Altitude'  = 0
        }
        'Balearic Islands'              = @{
            'Latitude'  = 39.5342
            'Longitude' = 2.8577
            'Altitude'  = 0
        }
        'Basque Country'                = @{
            'Latitude'  = 42.9896
            'Longitude' = -2.6189
            'Altitude'  = 0
        }
        'Canary Islands'                = @{
            'Latitude'  = 28.2916
            'Longitude' = -16.6291
            'Altitude'  = 0
        }
        'Cantabria'                     = @{
            'Latitude'  = 43.1828
            'Longitude' = -3.9878
            'Altitude'  = 0
        }
        'Castile and Leon'              = @{
            'Latitude'  = 41.8357
            'Longitude' = -4.3976
            'Altitude'  = 0
        }
        'Castile-La Mancha'             = @{
            'Latitude'  = 39.2796
            'Longitude' = -3.0977
            'Altitude'  = 0
        }
        'Catalonia'                     = @{
            'Latitude'  = 41.5912
            'Longitude' = 1.5209
            'Altitude'  = 0
        }
        'Ceuta'                         = @{
            'Latitude'  = 35.8890
            'Longitude' = -5.3213
            'Altitude'  = 0
        }
        'Extremadura'                   = @{
            'Latitude'  = 39.4937
            'Longitude' = -6.0679
            'Altitude'  = 0
        }
        'Galicia'                       = @{
            'Latitude'  = 42.5751
            'Longitude' = -8.1339
            'Altitude'  = 0
        }
        'La Rioja'                      = @{
            'Latitude'  = 42.2871
            'Longitude' = -2.5396
            'Altitude'  = 0
        }
        'Madrid'                        = @{
            'Latitude'  = 40.4168
            'Longitude' = -3.7038
            'Altitude'  = 0
        }
        'Melilla'                       = @{
            'Latitude'  = 35.2923
            'Longitude' = -2.9381
            'Altitude'  = 0
        }
        'Murcia'                        = @{
            'Latitude'  = 37.9922
            'Longitude' = -1.1307
            'Altitude'  = 0
        }
        'Navarre'                       = @{
            'Latitude'  = 42.6954
            'Longitude' = -1.6761
            'Altitude'  = 0
        }
        'Valencian Community'           = @{
            'Latitude'  = 39.4840
            'Longitude' = -0.7533
            'Altitude'  = 0
        }
        'Sweden'                        = @{
            'Latitude'  = 60.1282
            'Longitude' = 18.6435
            'Altitude'  = 0
        }
        'Switzerland'                   = @{
            'Latitude'  = 46.8182
            'Longitude' = 8.2275
            'Altitude'  = 0
        }
        'Turkey'                        = @{
            'Latitude'  = 38.9637
            'Longitude' = 35.2433
            'Altitude'  = 0
        }
        'Ukraine'                       = @{
            'Latitude'  = 48.3794
            'Longitude' = 31.1656
            'Altitude'  = 0
        }
        'England'                       = @{
            'Latitude'  = 52.3555
            'Longitude' = -1.1743
            'Altitude'  = 0
        }
        'Northern Ireland'              = @{
            'Latitude'  = 54.7877
            'Longitude' = -6.4923
            'Altitude'  = 0
        }
        'Scotland'                      = @{
            'Latitude'  = 56.4907
            'Longitude' = -4.2026
            'Altitude'  = 0
        }
        'Wales'                         = @{
            'Latitude'  = 52.1307
            'Longitude' = -3.7837
            'Altitude'  = 0
        }
        'Vatican City'                  = @{
            'Latitude'  = 41.9029
            'Longitude' = 12.4534
            'Altitude'  = 0
        }
        #endregion Europe
        #region North and Central America
        # TODO: Fill in the remaining countries
        #endregion North and Central America
        #region South America
        'Argentina'                     = @{
            'Latitude'  = -38.4161
            'Longitude' = -63.6167
            'Altitude'  = 0
        }
        'Bolivia'                       = @{
            'Latitude'  = -16.2902
            'Longitude' = -63.5887
            'Altitude'  = 0
        }
        'Brazil'                        = @{
            'Latitude'  = -14.2350
            'Longitude' = -51.9253
            'Altitude'  = 0
        }
        'Chile'                         = @{
            'Latitude'  = -35.6751
            'Longitude' = -71.5430
            'Altitude'  = 0
        }
        'Colombia'                      = @{
            'Latitude'  = 4.5709
            'Longitude' = -74.2973
            'Altitude'  = 0
        }
        'Ecuador'                       = @{
            'Latitude'  = -1.8312
            'Longitude' = -78.1834
            'Altitude'  = 0
        }
        'Guyana'                        = @{
            'Latitude'  = 4.8604
            'Longitude' = -58.9302
            'Altitude'  = 0
        }
        'Paraguay'                      = @{
            'Latitude'  = -23.4425
            'Longitude' = -58.4438
            'Altitude'  = 0
        }
        'Peru'                          = @{
            'Latitude'  = -9.1900
            'Longitude' = -75.0152
            'Altitude'  = 0
        }
        'Suriname'                      = @{
            'Latitude'  = 3.9193
            'Longitude' = -56.0278
            'Altitude'  = 0
        }
        'Uruguay'                       = @{
            'Latitude'  = -32.5228
            'Longitude' = -55.7658
            'Altitude'  = 0
        }
        'Venezuela'                     = @{
            'Latitude'  = 6.4238
            'Longitude' = -66.5897
            'Altitude'  = 0
        }

    }

    if ($ReturnAddress.IsPresent) {
        return $geoData.Keys
    }

    if ($geoData.ContainsKey($Address)) {
        return New-Object Windows.Devices.Geolocation.BasicGeoposition -Property $geoData[$Address]
    } else {
        throw [System.Configuration.ConfigurationException]::new("Address '{0}' not found in geo data. Please specify a valid address." -f $Address)
    }
}

function Get-OfflineMapPackage {
    [CmdletBinding()]
    [OutputType([Windows.Services.Maps.OfflineMaps.OfflineMapPackage])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Address,

        [Parameter()]
        [switch] $SinglePackageOnly
    )

    $geoCoordinate = Get-GeoLocationCoordinate -Address $Address
    $retryCount = 0
    $maxRetries = 5
    $offlineMapPackage = $null

    $offlineMapPackage = [Windows.Services.Maps.OfflineMaps.OfflineMapPackage]::FindPackagesAsync.Invoke($geoCoordinate)

    do {
        Start-Sleep -Seconds 1
        $offlineMapPackageStatus = $offlineMapPackage.Status
        if ($offlineMapPackageStatus -eq 'Completed') {
            $offlineMapPackage = $offlineMapPackage.GetResults()
            break
        } elseif ($offlineMapPackageStatus -eq 'Failed') {
            throw 'Failed to retrieve offline map package.'
        }
        $retryCount++
    } while ($retryCount -lt $maxRetries)

    if ($null -eq $offlineMapPackage.Packages) {
        throw 'No offline map package found with coordinates: {0}' -f ($geoCoordinate | ConvertTo-Json | Out-String)
    }

    return $offlineMapPackage
}

function Test-OfflineMapPackageStatus {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [Windows.Services.Maps.OfflineMaps.OfflineMapPackageQueryResult] $OfflineMapPackageResult,

        [Parameter(Mandatory = $true)]
        [string] $DisplayName
    )

    $package = $OfflineMapPackageResult.Packages | Where-Object { $_.DisplayName -eq $DisplayName }

    if ($null -eq $package) {
        return $false
    }

    if ($package.Status -ne 'Downloaded') {
        return $false
    }

    return $true
}

function Invoke-DownloadOfflineMapPackage {
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param (
        [Parameter(Mandatory = $true)]
        [Windows.Services.Maps.OfflineMaps.OfflineMapPackageQueryResult] $OfflineMapPackageResult
    )

    $inputObject = [System.Collections.ArrayList]@()

    foreach ($package in $OfflineMapPackageResult.Packages) {
        $packageProperties = @{
            'DisplayName' = $package.DisplayName
            'Region'      = $package.EnclosingRegionName
            'Status'      = $package.Status
            'Size'        = [math]::Round($package.EstimatedSizeInBytes / 1MB, 2)
        }

        if ($package.Status -ne 'Downloaded') {
            $package.RequestStartDownloadAsync() | Out-Null
            $retryCount = 0
            $maxRetries = 20

            do {
                Write-Verbose -Message "Downloading offline map package: $($package.DisplayName) attempt '$retryCount'"
                Start-Sleep -Seconds 30
            }
            while ($package.Status -ne 'Downloaded' -and $retryCount -lt $maxRetries)

            if ($package.Status -ne 'Downloaded') {
                Write-Warning "Failed to download offline map package: $($package.DisplayName) after $maxRetries attempts."

                continue
            }

            $packageProperties['Status'] = $package.Status
        }

        $inputObject.Add((New-Object PSObject -Property $packageProperties))
    }

    return $inputObject
}

#endregion Functions

#region Classes
<#
.SYNOPSIS
    The `AdvancedAppSettings` DSC Resource allows you to manage advanced application settings on Windows, including app source preferences, device experience sharing, and app archiving.

.PARAMETER SID
    The security identifier. This is a key property and should not be set manually.

.PARAMETER AppSourcePreference
    Specifies the source preference for installing applications. Possible values are: Anywhere, Recommendations, PreferStore, StoreOnly.

.PARAMETER ShareDeviceExperience
    Specifies the device experience sharing setting. Possible values are: Off, Device, Everyone.

.PARAMETER ArchiveApp
    Indicates whether to enable app archiving. This is an optional parameter.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name AdvancedAppSettings -Method Set -Property @{
        AppSourcePreference = 'PreferStore';
        ShareDeviceExperience = 'Everyone';
        ArchiveApp = $true;
    }

    This example sets the advanced app settings for the specified user to prefer store apps, share device experience with everyone, and enable app archiving.
#>
[DscResource()]
class AdvancedAppSettings {
    # Key required. Do not set.
    [DscProperty(Key)]
    [string] $SID

    [DscProperty()]
    [AppSourcePreference] $AppSourcePreference

    [DscProperty()]
    [ShareDeviceExperience] $ShareDeviceExperience

    [DscProperty()]
    [nullable[bool]] $ArchiveApp

    static hidden [string] $AppSourcePreferenceProperty = 'AicEnabled'
    static hidden [string] $ShareDeviceExperienceProperty1 = 'RomeSdkChannelUserAuthzPolicy'
    static hidden [string] $ShareDeviceExperienceProperty2 = 'CdpSessionUserAuthzPolicy'
    static hidden [string] $ArchiveAppProperty = 'EnableAppOffloading'

    [AdvancedAppSettings] Get() {
        $currentState = [AdvancedAppSettings]::new()
        $currentState.AppSourcePreference = [AdvancedAppSettings]::GetAppSourcePreference()
        $currentState.ShareDeviceExperience = [AdvancedAppSettings]::GetShareDeviceExperience()
        $currentState.ArchiveApp = [AdvancedAppSettings]::GetArchiveApp()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.AppSourcePreference) -and ($this.AppSourcePreference -ne $currentState.AppSourcePreference)) {
            return $false
        }

        if (($null -ne $this.ShareDeviceExperience) -and ($this.ShareDeviceExperience -ne $currentState.ShareDeviceExperience)) {
            return $false
        }

        if (($null -ne $this.ArchiveApp) -and ($this.ArchiveApp -ne $currentState.ArchiveApp)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            Set-AdvancedAppSettings -AppSourcePreference $this.AppSourcePreference -ShareDeviceExperience $this.ShareDeviceExperience -ArchiveApp $this.ArchiveApp
        }
    }

    #region AdvancedAppSettings helper functions
    static [AppSourcePreference] GetAppSourcePreference() {
        $preference = try {
            # Catching it this way. See issue: https://github.com/PowerShell/PowerShell/issues/5906
            Get-ItemPropertyValue -Path $global:ExplorerPath -Name ([AdvancedAppSettings]::AppSourcePreferenceProperty) -ErrorAction Stop
        } catch {
            'Anywhere'
        }

        return [AppSourcePreference]::$preference
    }

    static [ShareDeviceExperience] GetShareDeviceExperience() {
        # Assuming that if the first property does not exist, the second one will not exist either.
        if (-not (DoesRegistryKeyPropertyExist -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1))) {
            return [ShareDeviceExperience]::Off
        } else {
            $deviceExperience = Get-ItemPropertyValue -Path $global:CdpPath -Name ([AdvancedAppSettings]::ShareDeviceExperienceProperty1)
            $experience = switch ($deviceExperience) {
                0 { [ShareDeviceExperience]::Off }
                1 { [ShareDeviceExperience]::Device }
                2 { [ShareDeviceExperience]::Everyone }
                default { [ShareDeviceExperience]::Off }
            }

            return $experience
        }
    }

    static [bool] GetArchiveApp() {
        if (-not (DoesRegistryKeyPropertyExist -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty))) {
            return $true
        } else {
            $archiveValue = Get-ItemPropertyValue -Path $global:ArchiveAppPath -Name ([AdvancedAppSettings]::ArchiveAppProperty)
            return ($archiveValue -eq 1)
        }
    }
}

<#
.SYNOPSIS
    The `AppExecutionAliases` DSC Resource allows you to manage execution aliases for applications on Windows.

.PARAMETER ExecutionAliasName
    The name of the execution alias. This is a key property.

.PARAMETER Exist
    Indicates whether the execution alias should exist. This is an optional parameter.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name AppExecutionAliases -Method Set -Property @{
        ExecutionAliasName = 'myAppAlias.exe';
        Exist = $true;
    }

    This example ensures that the execution alias 'myAppAlias.exe' exists.
#>
[DscResource()]
class AppExecutionAliases {
    [DscProperty(Key, Mandatory)]
    [string] $ExecutionAliasName

    [DscProperty()]
    [bool] $Exist = $true

    AppExecutionAliases () {
    }

    AppExecutionAliases ([string] $ExecutionAliasName) {
        $this.ExecutionAliasName = $ExecutionAliasName
        $this.Exist = (Test-Path -Path "$global:AppPath\$ExecutionAliasName")
    }

    [AppExecutionAliases[]] Get() {
        $currentState = [AppExecutionAliases]::new($this.ExecutionAliasName)

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($this.Exist -ne $currentState.Exist) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            Set-AppExecutionAlias -ExecutionAliasName $this.ExecutionAliasName -Exist $this.Exist
        }
    }
}

<#
.SYNOPSIS
    The `OfflineMap` DSC Resource allows you to manage offline maps on Windows.

.PARAMETER OfflineMap
    The name of the offline map. This is a key property and should be set.

.PARAMETER Exist
    Indicates whether the offline map should exist. This is an optional parameter.

.EXAMPLE
    PS C:\> Invoke-DscResource -ModuleName Microsoft.Windows.Setting.Apps -Name OfflineMap -Method Set -Property @{
        DownloadMap = 'France';
        Exist = $true;
    }

    This example ensures that the offline map of France exists on your local machine.
#>
[DscResource()]
class OfflineMap {
    [DscProperty(Key, Mandatory)]
    [string] $DownloadMap

    [DscProperty()]
    [bool] $Exist = $true

    static [PSObject] $InstalledMap

    [OfflineMap] Get() {
        if ([String]::IsNullOrWhiteSpace($this.DownloadMap)) {
            throw 'A value must be provided for OfflineMap::DownloadMap'
        }

        $map = [OfflineMap]::GetDownloadMapStatus($this.DownloadMap)

        $currentState = [OfflineMap]::new()
        $currentState.DownloadMap = $this.DownloadMap
        $currentState.Exist = $map.Status

        # Add map object to installed map
        [OfflineMap]::InstalledMap = $map.Package

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if ($this.Exist -ne $currentState.Exist) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            if ($this.Exist) {
                Invoke-DownloadOfflineMapPackage -OfflineMapPackageResult ([OfflineMap]::InstalledMap)
            } else {
                # TODO: Implement removal
            }
        }
    }

    #region OfflineMap helper functions
    static [hashtable] GetDownloadMapStatus([string] $DownloadMap) {
        $packages = Get-OfflineMapPackage -Address $DownloadMap
        $status = Test-OfflineMapPackageStatus -OfflineMapPackageResult $packages -DisplayName $DownloadMap

        return @{
            Package = $packages
            Status  = $status
        }
    }
    #endregion OfflineMap helper functions
}
#endregion Classes
