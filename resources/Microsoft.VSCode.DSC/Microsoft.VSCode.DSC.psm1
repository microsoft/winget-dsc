# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

enum Ensure
{
    Absent
    Present
}

#region DSCResources
[DSCResource()]
class VSCodeExtension
{
    # Key required. Do not set.
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [string] $Version

    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    [DscProperty(NotConfigurable)]
    [hashtable] $InstalledExtensions = @{}

    [VSCodeExtension] Get()
    {
        # Get all installed extensions
        # Check if visual studio code is installed.

        Assert-VSCode

        $currentState = [VSCodeExtension]::new()
        $currentState.Ensure = [Ensure]::Absent
        $currentState.Name = $this.Name
        $currentState.Version = $this.Version
        $extensionList = (Invoke-VSCode -Command "--list-extensions --show-versions") -Split [Environment]::NewLine

        foreach ($extension in $extensionList)
        {
            $info = $extension -Split '@'
            $extensionName = $info[0]
            $extensionVersion = $info[1]
            $currentState.InstalledExtensions[$extensionName] = $extensionVersion
        }

        foreach ($extension in $currentState.InstalledExtensions.Keys)
        {
            if ($extension -eq $this.Name)
            {
                # if version parameter is provided.
                if ($null -ne $this.Version)
                {
                    if ($this.Version -eq $currentState.InstalledExtensions[$this.Name])
                    {
                        $currentState.Ensure = [Ensure]::Present
                    }
                }
                else
                {
                    $currentState.Ensure = [Ensure]::Present
                }

                break
            }
        }
        
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        if ($this.Ensure -eq [Ensure]::Present)
        {
            $extensionArg = $this.Name

            if ($null -ne $this.Version)
            {
                $extensionArg += "@$($this.Version)"
            }

            Invoke-VSCode -Command "--install-extension $($extensionArg)"
        }
        else
        {
            Invoke-VSCode -Command "--uninstall-extension $($this.Name)"
        }

    }
}

function Assert-VSCode
{
    # Refresh session $path value before invoking 'code'
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    try
    {
        Invoke-VSCode -Command '--help'
        return
    }
    catch
    {
        throw "VSCode is not installed"
    }
}

function Invoke-VSCode
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return Invoke-Expression -Command "code $Command"
}
