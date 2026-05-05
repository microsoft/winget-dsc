<#
.SYNOPSIS
  Log the runner's state before a flow runs. Pure diagnostics; never fails CI.
#>

$ErrorActionPreference = 'Continue'

Write-Host '==== preflight ===='
Write-Host "Date (UTC):      $((Get-Date).ToUniversalTime().ToString('o'))"
Write-Host "Host:            $env:COMPUTERNAME"
Write-Host "User:            $env:USERNAME"
Write-Host "PowerShell:      $($PSVersionTable.PSVersion)"
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    Write-Host "OS:              $($os.Caption) $($os.Version) build $($os.BuildNumber)"
} catch {
    Write-Host "OS:              (Get-CimInstance failed: $($_.Exception.Message))"
}

try {
    $wv = (winget --version) 2>$null
    Write-Host "winget:          $wv"
} catch {
    Write-Host "winget:          not available"
}

try {
    $drive = Get-PSDrive -Name C -ErrorAction Stop
    $freeGb = [math]::Round($drive.Free / 1GB, 2)
    $usedGb = [math]::Round($drive.Used / 1GB, 2)
    Write-Host "Disk C: free=${freeGb}GB used=${usedGb}GB"
} catch {
    Write-Host "Disk:            (query failed: $($_.Exception.Message))"
}

Write-Host '==== /preflight ===='
