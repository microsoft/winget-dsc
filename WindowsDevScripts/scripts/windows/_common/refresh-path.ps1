<#
.SYNOPSIS
  Refresh $env:PATH (and a few related vars) in the current PowerShell session
  by re-reading Machine + User environment from the registry.

.DESCRIPTION
  Windows installers (including winget packages) update the registry copy of
  PATH but do not update the PATH of already-running processes. Without this,
  a script that installs Node.js will not see `node.exe` in the same session.
#>

$ErrorActionPreference = 'Stop'

function Get-EnvFromRegistry {
    param(
        [Parameter(Mandatory)] [ValidateSet('Machine', 'User')] [string] $Scope,
        [Parameter(Mandatory)] [string] $Name
    )
    if ($Scope -eq 'Machine') {
        $key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    } else {
        $key = 'HKCU:\Environment'
    }
    try {
        return (Get-ItemProperty -Path $key -Name $Name -ErrorAction Stop).$Name
    } catch {
        return $null
    }
}

$machinePath = Get-EnvFromRegistry -Scope Machine -Name 'Path'
$userPath    = Get-EnvFromRegistry -Scope User    -Name 'Path'

$combined = @($machinePath, $userPath) |
    Where-Object { $_ } |
    ForEach-Object { $_.TrimEnd(';') } |
    Where-Object { $_ } |
    ForEach-Object { $_ -split ';' } |
    Where-Object { $_ -and $_.Trim() } |
    Select-Object -Unique

$env:Path = ($combined -join ';')

# Some tools read these instead of (or in addition to) PATH.
foreach ($n in @('PATHEXT', 'PSModulePath')) {
    $m = Get-EnvFromRegistry -Scope Machine -Name $n
    $u = Get-EnvFromRegistry -Scope User    -Name $n
    $v = @($m, $u) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd(';') } | Where-Object { $_ }
    if ($v) { Set-Item -Path "Env:$n" -Value ($v -join ';') }
}

Write-Host "[refresh-path] PATH rehydrated ($($combined.Count) entries)"
