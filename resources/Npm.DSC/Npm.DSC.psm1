# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

# Assert once that NPM is already installed on the system.
Assert-Npm

$global:useNpmCmd = $false
$global:npmCmdPath = "$env:ProgramFiles\nodejs\npm.cmd"

#region DSCResources
[DSCResource()]
class InstallNpm
{
    # DSCResource requires a key. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [string]$packageDirectory

    [DscProperty()]
    [string]$arguments

    [DscProperty()]
    [bool]$global

    [DscProperty(NotConfigurable)]
    [bool]$installAvailable

    [InstallNpm] Get()
    {
        if (-not ([string]::IsNullOrEmpty($this.packageDirectory)))
        {
            VerifyDirectoryAndSetLocation -directoryPath $this.packageDirectory
        }

        # `npm list` returns a nonzero exit code if there are missing packages to install.
        $listResult = Invoke-NpmList
        $this.installAvailable = $listResult.ExitCode -ne 0

        return @{
            packageDirectory = $this.packageDirectory
            arguments = $this.arguments
            global = $this.global
            installAvailable = $this.installAvailable
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.installAvailable -eq $false
    }

    [void] Set()
    {
        if ($this.Test() -eq $false)
        {
            Invoke-NpmInstall -Arguments $this.arguments -Global $this.global
        }
    }
}

[DSCResource()]
class InstallNpmPackage
{
    # DSCResource requires a key. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty(Mandatory)]
    [string[]]$packages

    [DscProperty()]
    [string]$packageDirectory

    [DscProperty()]
    [string]$arguments

    [DscProperty()]
    [bool]$global

    [DscProperty(NotConfigurable)]
    [bool]$installedStatus

    [InstallNpmPackage] Get()
    {
        if (-not ([string]::IsNullOrEmpty($this.packageDirectory)))
        {
            VerifyDirectoryAndSetLocation -directoryPath $this.packageDirectory
        }

        # Set initial value of installedStatus to true so that if any of the packages are not installed, it returns false.
        $this.installedStatus = $true
        foreach ($package in $this.packages)
        {
            $localResult = Invoke-NpmList -PackageName $package -Global $this.global
            $this.installedStatus = $this.installedStatus -and ($localResult.ExitCode -eq 0) 
        }

        return @{
            SID = $this.SID
            packageDirectory = $this.packageDirectory
            packages = $this.packages
            arguments = $this.arguments
            installedStatus = $this.installedStatus
        }       
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.installedStatus
    }

    [void] Set()
    {
        if ($this.Test() -eq $false)
        {
            foreach ($package in $this.packages)
            {
                Invoke-NpmInstall -PackageName $package -Arguments $this.arguments -Global $this.global
            }
        }
    }
}

#endregion DSCResources

#region Functions
function Assert-Npm
{
    # Try invoking npm help with the alias. If it fails, switch to calling npm.cmd directly.
    # This may occur if npm is installed in the same shell window and the alias is not updated until the shell window is restarted.
    try
    {
        Invoke-Npm -command 'help'
        return
    }
    catch {}

    if (Test-Path -Path $global:npmCmdPath)
    {
        $global:useNpmCmd = $true;
        Write-Host "Calling npm.cmd directly located at: $global:useNpmCmd"
    }
    else
    {
        throw "NodeJS is not installed"
    }
}

function Invoke-NpmInstall
{
    param (
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments,

        [Parameter()]
        [bool]$Global
    )

    $command = [List[string]]::new()
    $command.Add("install")
    $command.Add($PackageName)
    $command.Add($Arguments)

    if ($Global)
    {
        $command.Add("-g")
    }

    return Invoke-Npm -command $command
}

function Invoke-NpmList
{
    param (
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments,

        [Parameter()]
        [bool]$Global
    )

    $command = [List[string]]::new()
    $command.Add("list")
    $command.Add($PackageName)
    $command.Add($Arguments)

    if ($Global)
    {
        $command.Add("-g")
    }

    return Invoke-Npm -command $command
}

function Invoke-NpmUninstall
{
    param (
        [Parameter(Mandatory)]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add("uninstall")
    $command.Add($PackageName)
    $command.Add($Arguments)

    return Invoke-Npm -command $command    
}

function Invoke-Npm
{
    param (
        [Parameter(Mandatory)]
        [string]$command 
    )

    if ($global:useNpmCmd)
    {
        return Start-Process -FilePath $global:npmCmdPath -ArgumentList $command -Wait -PassThru -WindowStyle hidden
    }
    else
    {
        return Start-Process -FilePath npm -ArgumentList $command -Wait -PassThru -WindowStyle hidden
    }
}

function VerifyDirectoryAndSetLocation
{
    param (
        [Parameter(Mandatory)]
        [string]$directoryPath 
    )

    if (Test-Path -Path $directoryPath -PathType Container)
    {
        Set-Location -Path $directoryPath
    }
    else
    {
        throw "Path does not point to a valid directory."
    }
}

#endregion Functions