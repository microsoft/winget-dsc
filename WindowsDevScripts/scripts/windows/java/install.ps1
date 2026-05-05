<#
.SYNOPSIS
  Apply the Java winget DSC configuration on Windows.

.DESCRIPTION
  This script is a thin CI/dev shim. The core artifact for the Java flow is
  `configuration.winget` in this directory - a winget DSC configuration that
  declaratively installs the Microsoft Build of OpenJDK 21 (LTS) via winget.

  The shim exists only to:
    * apply the DSC config with retry (hosted-runner networks are flaky),
    * rehydrate PATH in the current session so later CI steps see `java`,
    * verify `java` and `javac` resolve, and
    * emit `INSTALL_OK: java` for the test harness.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

& (Join-Path $PSScriptRoot '..\_common\apply-configuration.ps1') `
    -Id              'java' `
    -ConfigFile      (Join-Path $PSScriptRoot 'configuration.winget') `
    -RequireCommands @('java', 'javac')
