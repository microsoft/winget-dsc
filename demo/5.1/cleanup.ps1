Remove-DscConfigurationDocument -Stage Current -CimSession localhost
rd .\OutDemo -Force -Recurse
rd 'C:\Program Files\WindowsPowerShell\Modules\WinDSCResourceDemo' -Force -Recurse
$regPath = "HKLM:SOFTWARE\WinDSCDemo"
if (Test-Path -Path $regPath)
{
    Remove-Item -Path $regPath -Recurse -Force
}