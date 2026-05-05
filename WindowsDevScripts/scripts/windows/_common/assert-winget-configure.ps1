<#
.SYNOPSIS
  Hard-fail preflight: assert that `winget configure` is available on this
  host. Every Windows flow in this repo -- and the CmdPal extension that
  launches them -- uses `winget configure` as its only install path. If it
  isn't wired up, there is nothing useful to do but bail with an
  actionable message.

.DESCRIPTION
  Failure modes this catches, in order of likelihood:

    1. winget (Microsoft.DesktopAppInstaller) is not installed at all, or
       is too old / broken to expose the `configure` subcommand.
    2. The `configuration` experimental feature flag is turned off in
       `winget settings` (`experimentalFeatures.configuration = false`).
       Only relevant on winget < 1.6; harmless to check on newer builds.
    3. Group Policy / MDM has disabled configure via the ADMX policy
       `EnableWindowsPackageManagerConfiguration` (registry value
       `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller\
       EnableWindowsPackageManagerConfiguration`, `0` = disabled).
    4. Running in a non-interactive context where the AppInstaller COM
       server cannot spin up (headless service accounts, SSH sessions
       without a desktop). We can't always detect this -- we just surface
       it as a fallback hint when the other checks pass but configure
       still errors.

  This script never "warns and continues" -- the whole point of this repo
  is `winget configure`, so a failure here is a stop-the-world condition.

.PARAMETER Quiet
  Suppress the "OK" line on success. Error output is always emitted.
#>

[CmdletBinding()]
param(
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# UTF-8 console encoding, matching winget's output. Without this, a
# `winget configure --help` probe under Windows PowerShell 5.1 prints
# garbled glyphs in the error message we surface. See issue #15.
try {
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = $utf8NoBom
    $OutputEncoding           = $utf8NoBom
} catch {
    Write-Verbose "Could not force UTF-8 console encoding: $($_.Exception.Message)"
}

function Test-ConfigurePolicyAllowed {
    # Returns $true if the GPO key is absent or set to anything other than 0.
    # Returns $false ONLY when the key is explicitly 0 (disabled by policy).
    $keyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller'
    try {
        $val = (Get-ItemProperty -Path $keyPath -Name 'EnableWindowsPackageManagerConfiguration' -ErrorAction Stop).EnableWindowsPackageManagerConfiguration
        return [int]$val -ne 0
    } catch {
        # Key or value absent => not policy-restricted.
        return $true
    }
}

# 1. winget itself must be present.
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wingetCmd) {
    throw @"
winget is not installed or not on PATH.

This repository's flows (and the CmdPal extension) require Windows Package
Manager (winget) with the `configure` subcommand. To fix:

  1. Install / update 'App Installer' from the Microsoft Store, or
  2. Grab the latest MSIX from
     https://github.com/microsoft/winget-cli/releases/latest
     (look for Microsoft.DesktopAppInstaller_*.msixbundle).

Then re-run your command.
"@
}

# 2. GPO / MDM check first -- cheapest, and its error message is the most
#    actionable, so surface it before the subprocess call.
if (-not (Test-ConfigurePolicyAllowed)) {
    throw @"
`winget configure` is disabled by Group Policy on this machine.

Registry key:
  HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller
  EnableWindowsPackageManagerConfiguration = 0

This is ADMX policy 'Enable Windows Package Manager Configuration'
(Computer Configuration > Administrative Templates > Windows Components >
App Installer). If this is your box, set the policy to 'Enabled' (or
delete the value) and reboot. If the box is domain-managed, file a
ticket with IT -- every flow in this repo depends on configure being
allowed.
"@
}

# 3. Probe the configure subcommand itself. `--help` is a pure no-op that
#    exits 0 iff the subcommand is wired up and the experimental flag
#    (if required) is on.
$helpOutput = & winget configure --help 2>&1
$helpExit   = $LASTEXITCODE

$looksRecognized = ($helpExit -eq 0) -and ($helpOutput -join "`n") -match '(?i)configuration|configure'

if (-not $looksRecognized) {
    throw @"
`winget configure --help` did not succeed on this machine
(exit=$helpExit). winget itself is present ($($wingetCmd.Source)) but the
`configure` subcommand is not wired up.

Output from `winget configure --help`:
--------
$($helpOutput -join [Environment]::NewLine)
--------

To fix, run the canonical remediation script (elevates via UAC):

  scripts\windows\_common\enable-winget-configure.ps1

It runs `winget configure --enable` and installs the required
Microsoft.VCRedist.2015+.x64 dependency, then re-verifies. The CmdPal
extension's red banner launches the same script. If you prefer to run
the steps by hand:

  winget configure --enable
  winget install -s winget --id Microsoft.VCRedist.2015+.x64 ``
      --accept-package-agreements --accept-source-agreements

Still failing after the script? Likely causes:

  1. App Installer itself is too old to know `--enable`. Update it:
       winget source update
       winget upgrade --id Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements
     or install the latest MSIX from
       https://github.com/microsoft/winget-cli/releases/latest

  2. You are running from a non-interactive session (SSH, Scheduled
     Task 'run whether user is logged on or not', headless service
     account). winget's configure path needs the AppInstaller COM
     server, which requires an interactive desktop. Re-run from a
     foreground PowerShell / Windows Terminal window.
"@
}

if (-not $Quiet) {
    $ver = (& winget --version) 2>$null
    Write-Host "winget configure: available ($ver)"
}
