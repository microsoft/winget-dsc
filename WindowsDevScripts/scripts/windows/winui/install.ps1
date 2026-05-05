<#
.SYNOPSIS
  Apply the WinUI 3 winget DSC configuration on Windows.

.DESCRIPTION
  This script is a thin CI/dev shim. The core artifact for the WinUI 3 flow
  is `configuration.winget` in this directory — a dscv3 winget DSC config
  that mirrors the canonical Microsoft Learn onboarding
  (https://learn.microsoft.com/windows/apps/get-started/start-here):
    * asserts minimum OS version,
    * enables Developer Mode,
    * installs Visual Studio 2026 Community, and
    * adds the .NET Desktop, UWP, and Windows App SDK C# workloads/components.

  The shim exists only to:
    * apply the DSC config with retry via `_common/apply-configuration.ps1`
      (which passes `--accept-configuration-agreements` and
      `--disable-interactivity`),
    * rehydrate PATH in the current session so later CI steps see `dotnet`,
    * verify `dotnet` resolves, and
    * emit `INSTALL_OK: winui` for the test harness.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

& (Join-Path $PSScriptRoot '..\_common\apply-configuration.ps1') `
    -Id              'winui' `
    -ConfigFile      (Join-Path $PSScriptRoot 'configuration.winget') `
    -RequireCommands @('dotnet')
