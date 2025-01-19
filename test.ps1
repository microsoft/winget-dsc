function Get-MouseSpeed() {

    $MethodDefinition = @'
        [DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref uint pvParam, uint fWinIni);
'@
    $User32 = Add-Type -MemberDefinition $MethodDefinition -Name 'User32Get' -Namespace Win32Functions -PassThru
    
    [Int32] $ScrollLines = 0
    $User32::SystemParametersInfo(0x0068, 0, [ref]$ScrollLines, 0) | Out-Null
    return $ScrollLines
}
    

function Set-MouseScrollLines {
    param (
        [Parameter()]
        [switch] $Enable,
        
        [Parameter()]
        [int] $Lines
    )

    $MethodDefinition = @'
        [DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref uint pvParam, uint fWinIni);
'@
    $User32 = Add-Type -MemberDefinition $MethodDefinition -Name 'User32MouseScrollLines' -Namespace Win32Functions -PassThru

    if (-not ($Enable.IsPresent)) {
        # If the -Enable switch is not present, we set the number to -1, meaning one screen at a time
        $Lines = -1
    }
    
    # Action: SPI_SETWHEELSCROLLLINES
    $Action = 0x0069
    $UpdateIniFile = 0x01
    $SendChangeEvent = 0x02

    $Options = $UpdateIniFile -bor $SendChangeEvent
    $Res = $User32::SystemParametersInfo($Action, $Lines, 0, $Options)

    if ($Res -ne 1) {
        throw [System.Configuration.ConfigurationException]::new('Failed to set the number of lines to scroll.')
    }
}

Add-Type -TypeDefinition @'
using System; 
using System.Runtime.InteropServices;
  
public class SystemParameters
{ 
    [DllImport("User32.dll",CharSet=CharSet.Unicode)] 
    public static extern int SystemParametersInfo(
        Int32 uAction,
        Int32 uParam,
        String lpvParam,
        Int32 fuWinIni);
}
'@

# 0x0014 = SPI_SETDESKWALLPAPER
$setWallpaperAction = 0x0069
$UpdateIniFile = 0x01
$SendChangeEvent = 0x02

$options = $UpdateIniFile -bor $SendChangeEvent

[SystemParameters]::SystemParametersInfo($setWallpaperAction, -1, 0, $options)