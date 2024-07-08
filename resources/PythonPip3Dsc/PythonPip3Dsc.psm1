# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

$global:usePip3Exe = $false
$global:pip3ExePath = "$env:LOCALAPPDATA\Programs\Python\Python38\Scripts\pip3.exe"

# Assert once that pip3 is already installed on the system.
Assert-Pip3

enum Ensure
{
    Absent
    Present
}

#region DSCResources
[DSCResource()]
class Pip3Package
{
    # DSCResource requires a key. Do not set.
    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty(Mandatory)]
    [string[]]$Packages

    [DscProperty()]
    [string]$Arguments

    [DscProperty(NotConfigurable)]
    [bool]$InstalledStatus

    [DscProperty(NotConfigurable)]
    [string[]]$InstalledPackages

    [Pip3Package] Get()
    {
        $this.InstalledPackages = GetInstalledPip3Packages | ConvertFrom-Json | Select-Object -ExpandProperty name
        $this.InstalledStatus = $true
        foreach ($package in $this.Packages)
        {
            $this.InstalledStatus = $this.InstalledPackages -contains $package
        }

        return @{
            SID = $this.SID
            Ensure = $this.Ensure
            Packages = $this.Packages
            Arguments = $this.Arguments
            InstalledStatus = $this.InstalledStatus
            InstalledPackages = $this.InstalledPackages
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        if ($currentState.Ensure -eq [Ensure]::Present)
        {
            return $currentState.InstalledStatus -eq $true
        }
        else
        {
            return $currentState.InstalledStatus -eq $false
        }
    }

    [void] Set()
    {
        $currentState = $this.Get()
        if ($currentState.Ensure -eq [Ensure]::Present)
        {
            if ($currentState.InstalledStatus -ne $true)
            {
                foreach ($package in $this.Packages)
                {
                    if ($currentState.InstalledPackages -notcontains $package)
                    {
                        Invoke-Pip3Install -PackageName $package -Arguments $this.Arguments
                    }
                }
            }
        }
        else
        {
            if ($currentState.InstalledStatus -ne $false)
            {
                foreach ($package in $this.Packages)
                {
                    if ($currentState.InstalledPackages -contains $package)
                    {
                        Invoke-Pip3Uninstall -PackageName $package -Arguments $this.Arguments
                    }
                }
            }
        }
    }
}

#endregion DSCResources

#region Functions
function Assert-Pip3
{
    # Try invoking pip3 help with the alias. If it fails, switch to calling npm.cmd directly.
    # This may occur if npm is installed in the same shell window and the alias is not updated until the shell window is restarted.
    try
    {
        Invoke-Pip3 -command 'help'
        return
    }
    catch {}

    if (Test-Path -Path $global:pip3ExePath)
    {
        $global:usePip3Exe = $true;
        Write-Host "Calling pip3.exe from default install location: $global:usePip3Exe"
    }
    else
    {
        throw "Python is not installed"
    }
}

function Invoke-Pip3Install
{
    param (
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add("install")
    $command.Add($PackageName)
    $command.Add($Arguments)
    return Invoke-Pip3 -command $command
}

function Invoke-Pip3Uninstall
{
    param (
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add("uninstall")
    $command.Add($PackageName)
    $command.Add($Arguments)

    # '--yes' is needed to ignore confrimation required for uninstalls
    $command.Add("--yes")
    return Invoke-Pip3 -command $command
}

function GetInstalledPip3Packages
{
    $Arguments = [List[string]]::new()
    $Arguments.Add("list")
    $Arguments.Add("--format=json")

    $command;
    if ($global:usePip3Exe)
    {
        $command = "& '$global:pip3ExePath' " + $Arguments
    }
    else
    {
        $command = "& pip3 " + $Arguments
    }

    return Invoke-Expression -Command $command
}

function Invoke-Pip3
{
    param (
        [Parameter(Mandatory)]
        [string]$command
    )

    if ($global:usePip3Exe)
    {
        return Start-Process -FilePath $global:pip3ExePath -ArgumentList $command -Wait -PassThru -WindowStyle hidden
    }
    else
    {
        return Start-Process -FilePath pip3 -ArgumentList $command -Wait -PassThru -WindowStyle hidden
    }
}

#endregion Functions