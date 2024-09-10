# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

enum VSCodeEnsure
{
    Absent
    Present
}

#region DSCResources
[DSCResource()]
class VSCodeExtension
{
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [string] $Version

    [DscProperty()]
    [VSCodeEnsure] $Ensure = [VSCodeEnsure]::Present

    [VSCodeExtension] Get()
    {
        $currentState = [VSCodeExtension]::new()
        $currentState.Ensure = [VSCodeEnsure]::Absent
        $currentState.Name = $this.Name
        $currentState.Version = $this.Version

        $installedExtensions = @{}
        $extensionList = (Invoke-VSCode -Command "--list-extensions --show-versions") -Split [Environment]::NewLine

        # Populate hash table with installed VSCode extensions.
        foreach ($extension in $extensionList)
        {
            $info = $extension -Split '@'
            $extensionName = $info[0]
            $extensionVersion = $info[1]
            $installedExtensions[$extensionName] = $extensionVersion
        }

        foreach ($extension in $installedExtensions.Keys)
        {
            if ($extension -eq $this.Name)
            {
                $currentState.Ensure = [VSCodeEnsure]::Present
                $currentState.Name = $extension
                $currentState.Version = $installedExtensions[$extension]
                break
            }
        }
        
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        if ($currentState.Ensure -ne $this.Ensure)
        {
            return $false
        }

        if ($null -ne $this.Version -and $this.Version -ne $currentState.Version)
        {
            return $false
        }

        return $true
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        if ($this.Ensure -eq [VSCodeEnsure]::Present)
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

function Invoke-VSCode
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    try 
    {
        return Invoke-Expression "& `"$env:LocalAppData\Programs\Microsoft VS Code\bin\code.cmd`" $Command"
    }
    catch
    {
        throw "VSCode is not installed."
    }
}
