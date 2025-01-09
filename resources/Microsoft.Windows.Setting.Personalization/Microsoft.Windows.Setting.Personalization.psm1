if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:DesktopPath = 'HKCU:\Control Panel\Desktop\'
    $global:ColorPath = 'HKCU:\Control Panel\Colors\'
    $global:WallPaperPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers\'
    $global:DesktopSlideShowPath = 'HKCU:\Control Panel\Personalization\Desktop Slideshow\'
    # TODO: Check if this value is cross all others
    $global:SlideShowPowerSetting = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\0d7dbae2-4294-402a-ba8e-26777e8488cd\309dce9b-bef4-4119-9921-a851fb12f0f4\'
    $global:DesktopSpotlightPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings\'
} else {
    $global:DesktopPath = $global:ColorPath = $global:WallPaperPath = $global:DesktopSlideShowPath = $global:SlideShowPowerSetting = $global:DesktopSpotlightPath = $env:TestRegistryPath
}

#region Enums
enum Style {
    Fill
    Fit
    Stretch
    Tile
    Center
    Span
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

function Get-OperatingSystemSKU {
    [CmdletBinding()]
    [OutputType('string')]
    param( [string] $Sku =
        (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSku)

    begin {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    }

    process {
        switch ($Sku) {
            0 { "An unknown product [$($SKU)]"; break; }
            1 { "Ultimate [$($SKU)]"; break; }
            2 { "Home Basic [$($SKU)]"; break; }
            3 { "Home Premium [$($SKU)]"; break; }
            4 { "Enterprise [$($SKU)]"; break; }
            5 { "Home Basic N [$($SKU)]"; break; }
            6 { "Business [$($SKU)]"; break; }
            7 { "Server Standard [$($SKU)]"; break; }
            8 { "Server Datacenter (full installation) [$($SKU)]"; break; }
            9 { "Windows Small Business Server [$($SKU)]"; break; }
            10 { "Server Enterprise (full installation) [$($SKU)]"; break; }
            11 { "Starter [$($SKU)]"; break; }
            12 { "Server Datacenter (core installation) [$($SKU)]"; break; }
            13 { "Server Standard (core installation) [$($SKU)]"; break; }
            14 { "Server Enterprise (core installation) [$($SKU)]"; break; }
            15 { "Server Enterprise for Itanium-based Systems [$($SKU)]"; break; }
            16 { "Business N [$($SKU)]"; break; }
            17 { "Web Server (full installation) [$($SKU)]"; break; }
            18 { "HPC Edition [$($SKU)]"; break; }
            19 { "Windows Storage Server 2008 R2 Essentials [$($SKU)]"; break; }
            20 { "Storage Server Express [$($SKU)]"; break; }
            21 { "Storage Server Standard [$($SKU)]"; break; }
            22 { "Storage Server Workgroup [$($SKU)]"; break; }
            23 { "Storage Server Enterprise [$($SKU)]"; break; }
            24 { "Windows Server 2008 for Windows Essential Server Solutions [$($SKU)]"; break; }
            25 { "Small Business Server Premium [$($SKU)]"; break; }
            26 { "Home Premium N [$($SKU)]"; break; }
            27 { "Enterprise N [$($SKU)]"; break; }
            28 { "Ultimate N [$($SKU)]"; break; }
            29 { "Web Server (core installation) [$($SKU)]"; break; }
            30 { "Windows Essential Business Server Management Server [$($SKU)]"; break; }
            31 { "Windows Essential Business Server Security Server [$($SKU)]"; break; }
            32 { "Windows Essential Business Server Messaging Server [$($SKU)]"; break; }
            33 { "Server Foundation [$($SKU)]"; break; }
            34 { "Windows Home Server 2011 [$($SKU)]"; break; }
            35 { "Windows Server 2008 without Hyper-V for Windows Essential Server Solutions [$($SKU)]"; break; }
            36 { "Server Standard without Hyper-V [$($SKU)]"; break; }
            37 { "Server Datacenter without Hyper-V (full installation) [$($SKU)]"; break; }
            38 { "Server Enterprise without Hyper-V (full installation) [$($SKU)]"; break; }
            39 { "Server Datacenter without Hyper-V (core installation) [$($SKU)]"; break; }
            40 { "Server Standard without Hyper-V (core installation) [$($SKU)]"; break; }
            41 { "Server Enterprise without Hyper-V (core installation) [$($SKU)]"; break; }
            42 { "Microsoft Hyper-V Server [$($SKU)]"; break; }
            43 { "Storage Server Express (core installation) [$($SKU)]"; break; }
            44 { "Storage Server Standard (core installation) [$($SKU)]"; break; }
            45 { "Storage Server Workgroup (core installation) [$($SKU)]"; break; }
            46 { "Storage Server Enterprise (core installation) [$($SKU)]"; break; }
            46 { "Storage Server Enterprise (core installation) [$($SKU)]"; break; }
            47 { "Starter N [$($SKU)]"; break; }
            48 { "Professional [$($SKU)]"; break; }
            49 { "Professional N [$($SKU)]"; break; }
            50 { "Windows Small Business Server 2011 Essentials [$($SKU)]"; break; }
            51 { "Server For SB Solutions [$($SKU)]"; break; }
            52 { "Server Solutions Premium [$($SKU)]"; break; }
            53 { "Server Solutions Premium (core installation) [$($SKU)]"; break; }
            54 { "Server For SB Solutions EM [$($SKU)]"; break; }
            55 { "Server For SB Solutions EM [$($SKU)]"; break; }
            56 { "Windows MultiPoint Server [$($SKU)]"; break; }
            59 { "Windows Essential Server Solution Management [$($SKU)]"; break; }
            60 { "Windows Essential Server Solution Additional [$($SKU)]"; break; }
            61 { "Windows Essential Server Solution Management SVC [$($SKU)]"; break; }
            62 { "Windows Essential Server Solution Additional SVC [$($SKU)]"; break; }
            63 { "Small Business Server Premium (core installation) [$($SKU)]"; break; }
            64 { "Server Hyper Core V [$($SKU)]"; break; }
            72 { "Server Enterprise (evaluation installation) [$($SKU)]"; break; }
            76 { "Windows MultiPoint Server Standard (full installation) [$($SKU)]"; break; }
            77 { "Windows MultiPoint Server Premium (full installation) [$($SKU)]"; break; }
            79 { "Server Standard (evaluation installation) [$($SKU)]"; break; }
            80 { "Server Datacenter (evaluation installation) [$($SKU)]"; break; }
            84 { "Enterprise N (evaluation installation) [$($SKU)]"; break; }
            95 { "Storage Server Workgroup (evaluation installation) [$($SKU)]"; break; }
            96 { "Storage Server Standard (evaluation installation) [$($SKU)]"; break; }
            98 { "Windows 8 N [$($SKU)]"; break; }
            99 { "Windows 8 China [$($SKU)]"; break; }
            100 { "Windows 8 Single Language [$($SKU)]"; break; }
            101 { "Windows 8 [$($SKU)]"; break; }
            103 { "Professional with Media Center [$($SKU)]"; break; }
            default { 'UNKNOWN: ' + $SKU }
        }
    }

    end {
        Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
    }

}

function Test-OperatingSystemSKU {
    $osSKU = Get-OperatingSystemSKU

    if ($osSKU -contains 'Professional') {
        return $false # Professional SKU is not supported
    }

    return $true
}

function Get-Style {
    $StyleInt = Get-ItemPropertyValue -Path $global:DesktopPath -Name 'WallPaperStyle'
    $StyleSize = switch ($StyleInt) {
        '0' { return ((Get-ItemPropertyValue -Path $global:DesktopPath -Name 'TileWallpaper') -eq 1 ? [Style]::Tile : [Style]::Center) }
        '2' { return [Style]::Stretch }
        '6' { return [Style]::Fit }
        '10' { return [Style]::Fill }
        '22' { return [Style]::Span }
        default { return [Style]::Fill }
    }

    return $StyleSize
}

function Test-Picture ($BackgroundPicture) {
    if (-not (Test-Path $BackgroundPicture)) {
        return $false
    }

    $extension = [System.IO.Path]::GetExtension($BackgroundPicture).ToLower()
    # The list of supported image extensions for the desktop background
    $extensionList = @('.jpg', '.jpeg', '.bmp', '.dib', '.png', '.jfif', '.jpe', '.gif', '.tif', '.tiff', '.wdp', '.heic', '.heif', '.heics', '.heifs', '.hif', '.avci', '.avcs', '.avif', '.avifs', '.jxr', '.jxl')

    if ($extension -notin $extensionList) {
        return $false
    }

    return $true

}

function Test-ColorCode ($ColorCode) {
    if (-not $ColorCode) {
        return $false
    }

    $colorArray = $ColorCode.Split(',')
    if ($colorArray.Count -ne 3) {
        return $false
    }

    foreach ($color in $colorArray) {
        if ($color -notin (0..255)) {
            return $false
        }
    }

    return $true
}

function Test-AssemblyLoad {
    param (
        [Parameter()]
        [string] $AssemblyName = 'Params'
    )

    $assembly = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $AssemblyName }

    if (-not $assembly) {
        return $false
    }

    return $true
}

function Set-WallPaper {
    param (
        [Parameter(Mandatory)]
        [string] $Image,

        [Parameter()]
        [AllowNull()]
        [ValidateSet('Fill', 'Fit', 'Stretch', 'Tile', 'Center', 'Span')]
        [string] $Style = 'Fill',

        [Parameter()]
        [AllowNull()]
        [string] $Color
    )
    if (Test-Picture -BackgroundPicture $Image) {
        $WallpaperStyle = Switch ($Style) {
            'Fill' { '10' }
            'Fit' { '6' }
            'Stretch' { '2' }
            'Tile' { '0' }
            'Center' { '0' }
            'Span' { '22' }
            default { '10' }
        }

        New-ItemProperty -Path $global:DesktopPath -Name WallpaperStyle -PropertyType String -Value $WallpaperStyle -Force | Out-Null
        New-ItemProperty -Path $global:DesktopPath -Name TileWallpaper -PropertyType String -Value (($Style -eq 'Tile') ? 1 : 0) -Force | Out-Null

        if (-not ([string]::IsNullOrEmpty($Color))) {
            if (Test-ColorCode -ColorCode $Color) {
                $Color = $Color -replace ',', ' '
                Set-ItemProperty -Path $global:ColorPath -Name 'Background' -Value $Color
            }
        }

        if (-not (Test-AssemblyLoad)) {
            Add-Type -TypeDefinition @'
        using System;
        using System.Runtime.InteropServices;

        public class Params
        {
            [DllImport("User32.dll",CharSet=CharSet.Unicode)]
            public static extern int SystemParametersInfo (Int32 uAction,
                Int32 uParam,
                String lpvParam,
                Int32 fuWinIni);
        }
'@ -ErrorAction SilentlyContinue
        }


        $SPI_SETDESKWALLPAPER = 0x0014
        $UpdateIniFile = 0x01
        $SendChangeEvent = 0x02

        $fWinIni = $UpdateIniFile -bor $SendChangeEvent

        $ret = [Params]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $Image, $fWinIni)
    }
}

function Set-WallPaperEntryNull {
    if (-not ([String]::IsNullOrWhiteSpace(((Get-ItemPropertyValue -Path $global:DesktopPath -Name WallPaper))))) {
        Set-ItemProperty -Path $DesktopPath -Name WallPaper -Value $null
    }
}
#endregion Functions

#region Classes
<#
.SYNOPSIS
    The `BackgroundPicture` class contains DSC resources for configuring the desktop background picture.

.PARAMETER Picture
    The path to the image file that will be used as the desktop background picture.

.PARAMETER Style
    The style of the desktop background picture. The possible values are `Fill`, `Fit`, `Stretch`, `Tile`, `Center`, and `Span`.

.PARAMETER BackgroundColor
    The color of the desktop background. The value should be in the format `R,G,B`, where `R`, `G`, and `B` are the red, green, and blue color components, respectively.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name BackgroundPicture -Method Set -Property @{ Picture = 'C:\Pictures\Background.jpg'; Style = 'Fill'; BackgroundColor = '255,255,255' }

    This example sets the desktop background picture to `C:\Pictures\Background.jpg` with the `Fill` style and white background color.

.LINK
    For more information about color codes, see https://www.color-hex.com/
#>
[DscResource()]
class BackgroundPicture {
    [DscProperty(Key, Mandatory)]
    [string] $Picture

    [DscProperty()]
    [Style] $Style

    [DscProperty()]
    [string] $BackgroundColor

    BackgroundPicture() {
        $this.Style = Get-Style
    }

    BackgroundPicture([string] $Picture, [Style] $Style, [string] $BackgroundColor) {
        $this.Picture = $Picture
        $this.Style = $Style
        $this.BackgroundColor = $BackgroundColor
    }

    [BackgroundPicture] Get() {
        $currentState = [BackgroundPicture]::GetCurrentState()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()

        if (($null -ne $this.Picture) -and ($this.Picture -ne $currentState.Picture)) {
            return $false
        }
        if (($null -ne $this.Style) -and ($this.Style -ne $currentState.Style)) {
            return $false
        }
        if (($null -ne $this.BackgroundColor) -and ($this.BackgroundColor -ne $currentState.BackgroundColor)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            Set-WallPaper -Image $this.Picture -Style $this.Style -Color $this.BackgroundColor
        }
    }

    #region BackgroundPicture helper functions
    static [BackgroundPicture] GetCurrentState() {
        $WallPaper = Get-ItemPropertyValue -Path $global:DesktopPath -Name 'WallPaper'
        $Color = (Get-ItemPropertyValue -Path $global:ColorPath -Name 'Background') -replace ' ', ','
        $CurrentStyle = Get-Style

        return [BackgroundPicture]::new($WallPaper, $CurrentStyle, $Color)
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
    #endregion BackgroundPicture helper functions
}


<#
.SYNOPSIS
    The `BackgroundSolidColor` class contains DSC resources for configuring the desktop background color.

.PARAMETER BackgroundSolidColor
    The color of the desktop background. The value should be in the format `R,G,B`, where `R`, `G`, and `B` are the red, green, and blue color components, respectively.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name BackgroundSolidColor -Method Set -Property @{ BackgroundColor = '255,255,255' }

    This example sets the desktop background color to white.

.LINK
    For more information about color codes, see https://www.color-hex.com/
#>
[DscResource()]
class BackgroundSolidColor {
    [DscProperty(Key, Mandatory)]
    [string] $BackgroundColor

    [BackgroundSolidColor] Get() {
        $currentState = [BackgroundSolidColor]::new()
        $currentState.BackgroundColor = (Get-ItemPropertyValue -Path $global:ColorPath -Name 'Background') -replace ' ', ','

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($this.BackgroundColor -ne $currentState.BackgroundColor) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            if (Test-ColorCode -ColorCode $this.BackgroundColor) {
                $ColorCode = $this.BackgroundColor -replace ',', ' '
                Set-ItemProperty -Path $global:ColorPath -Name 'Background' -Value $ColorCode
                Set-WallPaperEntryNull # If the value is set to null, the color will take in effect
            }
            # TODO: Should we throw if color code is not correct?
        }
    }
}

<#
.SYNOPSIS
    The `BackgroundSlideShow` class contains DSC resources for configuring the desktop background slideshow.

.PARAMETER PictureAlbum
    The path to the folder containing the images for the slideshow.

.PARAMETER SlideDuration
    The duration for each slide in milliseconds. Valid values are '60000', '600000', '1800000', '3600000', '21600000', and '86400000'.

.PARAMETER Shuffle
    Indicates whether the slideshow should shuffle the images.

.PARAMETER PauseOnBattery
    Indicates whether the slideshow should pause when the device is on battery power.

.PARAMETER Style
    The style of the desktop background picture. The possible values are `Fill`, `Fit`, `Stretch`, `Tile`, `Center`, and `Span`.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name BackgroundSlideShow -Method Set -Property @{ PictureAlbum = 'C:\Pictures\Album'; SlideDuration = '1800000'; Shuffle = $true; PauseOnBattery = $true; Style = 'Fill' }

    This example sets the desktop background slideshow to use images from `C:\Pictures\Album` with a slide duration of 30 minutes, shuffling enabled, pausing on battery, and the `Fill` style.
#>
[DscResource()]
class BackgroundSlideShow {
    [DscProperty(Key)]
    [string] $PictureAlbum

    [DscProperty()]
    [ValidateSet('60000', '600000', '1800000', '3600000', '21600000', '86400000')]
    [int] $SlideDuration = '1800000'

    [DscProperty()]
    [bool] $Shuffle = $false

    [DscProperty()]
    [bool] $PauseOnBattery = $false

    [DscProperty()]
    [Style] $Style

    [BackgroundSlideShow] Get() {
        $currentState = [BackgroundSlideShow]::new()
        $currentState.PictureAlbum = 'Not implemented'
        $currentState.SlideDuration = Get-ItemPropertyValue -Path $global:DesktopSlideShowPath -Name 'Interval'
        $currentState.Shuffle = Get-ItemPropertyValue -Path $global:DesktopSlideShowPath -Name 'Shuffle'
        $currentState.PauseOnBattery = Get-ItemPropertyValue -Path $global:SlideShowPowerSetting -Name 'DCSettingIndex' -ErrorAction SilentlyContinue

        return $currentState
    }

    [bool] Test() {
        return $true
    }

    [void] Set() {
        # Determine with function Test-OperatingSystemSKU if the SKU is supported. Clearly on Windows 11 professional, the slideshow is not supported.
    }
}

<#
.SYNOPSIS
    The `BackgroundWindowsSpotlight` class contains DSC resources for configuring the Windows Spotlight feature.

.PARAMETER EnableWindowsSpotlight
    Indicates whether the Windows Spotlight feature should be enabled.

.EXAMPLE
    PS C:\> Invoke-DscResource -Name BackgroundWindowsSpotlight -Method Set -Property @{ EnableWindowsSpotlight = $true }

    This example enables the Windows Spotlight feature.
#>
[DscResource()]
class BackgroundWindowsSpotlight {
    [DscProperty(Key)]
    [string] $SID

    [DscProperty()]
    [bool] $EnableWindowsSpotlight

    static hidden [string] $EnableSpotLightProperty = 'EnabledState'

    [BackgroundWindowsSpotlight] Get() {
        $currentState = [BackgroundWindowsSpotlight]::new()
        $currentState.EnableWindowsSpotlight = [BackgroundWindowsSpotlight]::GetCurrentState()

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($this.EnableWindowsSpotlight -ne $currentState.EnableWindowsSpotlight) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            Set-ItemProperty -Path $global:DesktopSpotlightPath -Name ([BackgroundWindowsSpotlight]::EnableSpotLightProperty) -Value (($this.EnableWindowsSpotlight) ? 1 : 0)
        }
    }

    #region BackgroundSpotlight helper functions
    static [bool] GetCurrentState() {
        if (-not(DoesRegistryKeyPropertyExist -Path $global:DesktopSpotlightPath -Name ([BackgroundWindowsSpotlight]::EnableSpotLightProperty))) {
            return $false
        } else {
            $EnabledState = Get-ItemPropertyValue -Path $global:DesktopSpotlightPath -Name ([BackgroundWindowsSpotlight]::EnableSpotLightProperty)

            return ($EnabledState -eq 1)
        }
    }
    #endregion BackgroundSpotlight helper functions
}

#endregion Classes
