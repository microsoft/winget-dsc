<#
.SYNOPSIS
  Apply the Rust winget DSC configuration on Windows.

.DESCRIPTION
  This script is a thin CI/dev shim. The core artifact for the Rust flow is
  `configuration.winget` in this directory - a winget DSC configuration that
  installs rustup via winget and then runs `rustup default stable` to bring
  in the stable Rust toolchain (rustc, cargo, ...).

  The shim exists only to:
    * apply the DSC config with retry (hosted-runner networks are flaky),
    * rehydrate PATH in the current session so later CI steps see `cargo`,
    * verify `rustc` and `cargo` resolve, and
    * emit `INSTALL_OK: rust` for the test harness.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

& (Join-Path $PSScriptRoot '..\_common\apply-configuration.ps1') `
    -Id              'rust' `
    -ConfigFile      (Join-Path $PSScriptRoot 'configuration.winget') `
    -RequireCommands @('rustc', 'cargo')
