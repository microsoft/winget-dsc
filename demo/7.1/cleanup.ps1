# Run as admin
Remove-DscConfigurationDocument -Stage Current -CimSession localhost

$regPath = "HKCU:SOFTWARE\WinDSCDemo"
if (Test-Path -Path $regPath)
{
    Remove-Item -Path $regPath -Recurse -Force
}