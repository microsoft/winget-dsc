# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

# Assert once that Yarn is already installed on the system.
Assert-Yarn

#region DSCResources
<#
    .SYNOPSIS
        The `YarnInstall` DSC resource is used to install all Yarn packages listed in a `package.json` file.

    .DESCRIPTION
        The `YarnInstall` DSC resource invokes `yarn install` to install all packages defined in a
        `package.json` file in the specified directory. It is inherently idempotent as Yarn will
        resolve all package dependencies on each run.

        ## Requirements

        * Target machine must have Yarn installed.

    .PARAMETER SID
        The security identifier. This is a key property and should not be set manually.

    .PARAMETER Arguments
        Additional arguments to pass to `yarn install`.

    .PARAMETER PackageDirectory
        The directory containing the `package.json` file. If not specified, the current directory is used.

    .PARAMETER Dependencies
        A read-only list of currently installed package dependencies. This property is not configurable.

    .EXAMPLE
        Invoke-DscResource -ModuleName YarnDsc -Name YarnInstall -Method Set -Property @{
            PackageDirectory = 'C:\repos\my-project'
        }

        This example installs all Yarn packages defined in `C:\repos\my-project\package.json`.
#>
[DSCResource()]
class YarnInstall {
    # DSCResource requires a key. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [string]$Arguments

    [DscProperty()]
    [string]$PackageDirectory

    [DscProperty(NotConfigurable)]
    [string[]]$Dependencies

    [YarnInstall] Get() {
        if (-not([string]::IsNullOrEmpty($this.PackageDirectory))) {
            if (Test-Path -Path $this.PackageDirectory -PathType Container) {
                Set-Location -Path $this.PackageDirectory
            } else {
                throw "$($this.PackageDirectory) does not point to a valid directory."
            }
        }

        $currentState = [YarnInstall]::new()
        $currentState.Dependencies = Invoke-YarnInfo -Arguments '--name-only --json' | ConvertFrom-Json
        $currentState.Arguments = $this.Arguments
        $currentState.PackageDirectory = $this.PackageDirectory
        return $currentState
    }

    [bool] Test() {
        # Yarn install is inherently idempotent as it will also resolve package dependencies. Set to $false
        return $false
    }

    [void] Set() {
        $currentState = $this.Get()
        Invoke-YarnInstall -Arguments $currentState.Arguments
    }
}

#endregion DSCResources

#region Functions
function Assert-Yarn {
    # Refresh session $path value before invoking 'npm'
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    try {
        Invoke-Yarn -Command 'help'
        return
    } catch {
        throw 'Yarn is not installed'
    }
}

function Invoke-YarnInfo {
    param(
        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add('info')
    $command.Add($Arguments)
    return Invoke-Yarn -Command $command
}

function Invoke-YarnInstall {
    param (
        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add('install')
    $command.Add($Arguments)
    return Invoke-Yarn -Command $command
}

function Invoke-Yarn {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return Invoke-Expression -Command "yarn $Command"
}

#endregion Functions
