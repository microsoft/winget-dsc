# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic
using namespace System.Diagnostics

#region DSCResources
[DSCResource()]
class InstallVSComponent
{
    [DscProperty(Key)]
    [string]$productId

    [DscProperty(Key)]
    [string]$channelId

    [DscProperty(Mandatory)]
    [string[]]$components

    [DscProperty(NotConfigurable)]
    [string[]]$installedComponents

    [InstallVSComponent] Get()
    {
        $this.installedComponents = Get-VsComponents -ProductId $this.productId

        return @{
            productId = $this.productId
            channelId = $this.channelId
            components = $this.components
            installedComponents = $this.installedComponents
        }
    }

    [bool] Test()
    {
        $this.Get()

        foreach ($component in $this.components)
        {
            if ($this.installedComponents -notcontains $component)
            {
                return $false
            }
        }  

        return $true
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        $vsConfigFilePath = CreateVSConfigFile -Version "1.0" -Components $this.components
        if (-not (Test-Path -Path $vsConfigFilePath))
        {
            throw "Failed to generate .vsconfig file."
        }

        Install-VsConfigFile -ProductId $this.productId -ChannelId $this.channelId -vsconfigFile $vsConfigFilePath
    }
}

[DSCResource()]
class InstallVSConfig
{
    [DscProperty(Key)]
    [string]$productId

    [DscProperty(Key)]
    [string]$channelId

    [DscProperty(Mandatory)]
    [string]$vsconfigFile

    [DscProperty(NotConfigurable)]
    [string[]]$installedComponents

    [InstallVSConfig] Get()
    {
        $this.installedComponents = Get-VsComponents -ProductId $this.productId

        return @{
            productId = $this.productId
            channelId = $this.channelId
            vsconfigFile = $this.vsconfigFile
            installedComponents = $this.installedComponents
        }
    }

    [bool] Test()
    {
        $this.Get()
        $components = Get-Content $this.vsconfigFile | Out-String | ConvertFrom-Json

        foreach ($component in $components)
        {
            if ($this.installedComponents -notcontains $component)
            {
                return $false
            }
        }  

        return $true
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        Install-VsConfigFile -ProductId $this.productId -ChannelId $this.channelId -vsconfigFile $this.vsconfigFile
    }
}
#endregion DSCResources

#region Functions
function CreateVSConfigFile
{
    param
    (
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string[]]$Components
    )

    $componentList = [System.Collections.ArrayList]$Components
    $vsConfig = @{}
    $vsConfig.Add("components", $componentList)
    $vsConfig.Add("version", $Version)

    $vsConfigFilePath = "$env:temp\.vsconfig"
    $vsConfig | ConvertTo-Json| Out-File $vsConfigFilePath -Force
    return $vsConfigFilePath
}

# Call setup.exe with the config file.
function Install-VsConfigFile
{
    param
    (
        [Parameter(Mandatory)]
        [string]$ProductId,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$VsconfigFile
    )
    
    $arguments = [List[string]]::new()
    $arguments.Add("modify")
    $arguments.Add("--productId")
    $arguments.Add($ProductId)
    $arguments.Add("--channelId")
    $arguments.Add($ChannelId)
    $arguments.Add("--config")
    $arguments.Add($VsconfigFile)
    $arguments.Add("--passive")

    Invoke-VsInstaller -Arguments $arguments
}

function Assert-IsAdministrator
{
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

    if (-not $windowsPrincipal.IsInRole($adminRole))
    {
        throw "This resource must be run as an Administrator."
    }
}

function Get-VSComponents
{
    param (
        [Parameter(Mandatory)]
        [string]$ProductId
    )

    $arguments = [List[string]]::new()
    $arguments.Add("-products")
    $arguments.Add($ProductId)
    $arguments.Add("-include packages -format json")

    $result = Invoke-VsWhere -Arguments $arguments | ConvertFrom-Json
    return $result.packages | Where-Object {$_.type -eq "Component"} | Select-Object -ExpandProperty id 
}

function Invoke-VsWhere
{
    param
    (
        [Parameter(Mandatory)]
        [List[string]]$Arguments
    )

    $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -Path $vswherePath))
    {
        throw "vswhere.exe not found"
    }

    # Invoke-Expression is used instead of Start-Process to retrieve output.
    $command = "& '$vswherePath' " + $Arguments
    return Invoke-Expression -Command $command
}

function Invoke-VsInstaller
{
    param
    (
        [Parameter(Mandatory)]
        [List[string]]$Arguments
    )

    # setup.exe call with --passive or --quiet requires admin.
    Assert-IsAdministrator

    $vsInstallerPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
    if (-not (Test-Path -Path $vsInstallerPath))
    {
        throw "setup.exe not found"
    }

    # Construct command.
    # Launch cmd and run the setup.exe command. Setup.exe prints the logs in PowerShell but when it completes, control is
    # not given back to powershell at the end of the console and the next Write-Host would end up writing at the top of the
    # window and it just looks weird. Making use of cmd by launching it in another window looks a lot cleaner.
    $command = "/c `"$vsInstallerPath`" " + $Arguments
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList $command -Wait -PassThru -WindowStyle Minimized
    if ($process.ExitCode -ne 0)
    {
        throw "Failed running setup.exe with args $Arguments Error: $($process.ExitCode)"
    }
}

#endregion Functions