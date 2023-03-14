# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

#region DSCResources

[DSCResource()]
class NpmInstall
{
    [DscProperty(Key)]
    [string]$packageName

    [DscProperty()]
    [string]$arguments

    [DscProperty(NotConfigurable)]
    [bool]$installedStatus

    [DscProperty(NotConfigurable)]
    [bool]$installedStatusGlobal

    [NpmInstall] Get()
    {
        $localResult = Invoke-NpmList -PackageName $this.packageName
        $this.installedStatus = $localResult.ExitCode -eq 0

        $globalResult = Invoke-NpmList -PackageName $this.packageName -Arguments '-g'
        $this.installedStatusGlobal = $globalResult.ExitCode -eq 0

        return @{
            packageName = $this.packageName
            arguments = $this.arguments
            installedStatus = $this.installedStatus
            installedStatusGlobal = $this.installedStatusGlobal
        }       
    }

    [bool] Test()
    {
        $this.Get()
        if ($this.arguments -contains "-g" -or $this.arguments -contains "--global")
        {
            return $this.installedStatusGlobal
        }
        else
        {
            return $this.installedStatus
        }
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        Invoke-NpmInstall -PackageName $this.packageName -Arguments $this.arguments
    }
}

#endregion DSCResources

#region Functions

function Invoke-NpmInstall
{
    param (
        [Parameter(Mandatory)]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add("install")
    $command.Add($PackageName)
    $command.Add($Arguments)

    return Invoke-Npm -command $command
}


function Invoke-NpmList
{
    param (
        [Parameter(Mandatory)]
        [string]$PackageName,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add("list")
    $command.Add($PackageName)
    $command.Add($Arguments)

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

    return Start-Process -FilePath npm -ArgumentList $command -Wait -PassThru
}


#endregion Functions