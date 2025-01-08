if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:DesktopPath = 'HKCU:\Control Panel\Desktop\'
    $global:ColorPath = 'HKCU:\Control Panel\Colors\'
    $global:WallPaperPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers\'
    $global:DesktopSpotlightPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings\'
} else {
    $global:DesktopPath = $global:ColorPath = $global:WallPaperPath = $global:DesktopSpotlightPath = $env:TestRegistryPath
}

#region Enums
enum Fit {
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

function Set-BackgroundSetting ($BackgroundPicture, $Fit, $BackgroundColor) {
    if ($BackgroundPicture) {
        if (Test-Picture -BackgroundPicture $BackgroundPicture) {
            Set-ItemProperty -Path $global:DesktopPath -Name 'WallPaper' -Value $BackgroundPicture
        }
    }

    if ($Fit) {
        $FitInt = switch ($Fit) {
            'Tile' { 0 }
            'Center' { 0 }
            'Stretch' { 2 }
            'Fit' { 6 }
            'Fill' { 10 }
            'Span' { 22 }
            default { 0 }
        }

        Set-ItemProperty -Path $global:DesktopPath -Name 'WallPaperStyle' -Value $FitInt
        Set-ItemProperty -Path $global:DesktopPath -Name 'TileWallpaper' -Value (($Fit -ne 'Tile') ? 0 : 1) # The rest is always zero

        if ($Fit -in 'Fit', 'Center') {
            if (Test-ColorCode -ColorCode $BackgroundColor) {
                $BackGroundColor = $BackgroundColor -replace ',', ' '
                Set-ItemProperty -Path $global:ColorPath -Name 'Background' -Value $BackgroundColor
            }
        }
    }
}

function Set-WallPaperEntryNull {
    if (-not ([String]::IsNullOrWhiteSpace(((Get-ItemPropertyValue -Path $global:DesktopPath -Name WallPaper))))) {
        Set-ItemProperty -Path $DesktopPath -Name WallPaper -Value $null
    }
}
#endregion Functions

#region Classes
[DscResource()]
class BackgroundPicture {
    [DscProperty(Key)]
    [string] $Picture

    [DscProperty()]
    [Fit] $Fit

    [DscProperty()]
    [string] $BackgroundColor

    BackgroundPicture() {
        $this.Fit = [BackgroundPicture]::GetFitStyle()
    }

    BackgroundPicture([string] $Picture, [Fit] $Fit, [string] $BackgroundColor) {
        $this.Picture = $Picture
        $this.Fit = $Fit
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
        if (($null -ne $this.Fit) -and ($this.Fit -ne $currentState.Fit)) {
            return $false
        }
        if (($null -ne $this.BackgroundColor) -and ($this.BackgroundColor -ne $currentState.BackgroundColor)) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if (-not ($this.Test())) {
            Set-BackgroundSetting -BackgroundPicture $this.Picture -Fit $this.Fit -BackgroundColor $this.BackgroundColor
        }
    }

    #region BackgroundPicture helper functions
    static [BackgroundPicture] GetCurrentState() {
        $WallPaper = Get-ItemPropertyValue -Path $global:DesktopPath -Name 'WallPaper'
        $Color = (Get-ItemPropertyValue -Path $global:ColorPath -Name 'Background') -replace ' ', ','
        $FitStyle = [BackgroundPicture]::GetFitStyle()

        return [BackgroundPicture]::new($WallPaper, $FitStyle, $Color)
    }

    static [Fit] GetFitStyle() {
        $FitInt = Get-ItemPropertyValue -Path $global:DesktopPath -Name 'WallPaperStyle'
        $FitSize = switch ($FitInt) {
            '0' { return ((Get-ItemPropertyValue -Path $global:DesktopPath -Name 'TileWallpaper') -eq 1 ? [Fit]::Tile : [Fit]::Center) }
            '2' { return [Fit]::Stretch }
            '6' { return [Fit]::Fit }
            '10' { return [Fit]::Fill }
            '22' { return [Fit]::Span }
            default { return [Fit]::Fill }
        }

        return $FitSize
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

# TODO: Create BackgroundSlideShow class

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
