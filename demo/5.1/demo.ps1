# Run as admin.

Set-ExecutionPolicy Unrestricted -Force

# copy module to "C:\Program Files\WindowsPowerShell\Modules\"
.\copyToModules.ps1

#ise WinDSCResourceDemo\WinDSCResourceDemo.psm1

# Load config
#ise WinDSCConfigDemo.ps1
.\WinDSCConfigDemo.ps1

#ise .\OutDemo\localhost.mof

#regedit

Start-DscConfiguration -Path ".\OutDemo" -Verbose -Wait -Force

Test-DscConfiguration -ComputerName localhost -Detailed | Format-List

# Delete a registry key
Remove-Item -Path "HKLM:SOFTWARE\WinDSCDemo\Rum\CaptainMorgan" -Force -Recurse

Test-DscConfiguration -ComputerName localhost -Detailed | Format-List

Start-DscConfiguration -Path ".\OutDemo" -Verbose -Wait -Force

.\cleanup.ps1
