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

# VisualStudioExtension installs a vsix extension using setup.exe. We can make it such as it takes the Publisher, Name
# and Version or the URL of the vsix extension (we use the former to construct the URL). If Version is null we use latest.
[DSCResource()]
class InstallVSExtension
{
    # TODO: figure out what's the best. Having ProductId and ChannelId as key when we can have multiple of them sounds weird.
    # If we end up having a VsixUrl then is a conditional key?
    [DscProperty(Key)]
    [string]$ProductId

    [DscProperty(Key)]
    [string]$Publisher

    [DscProperty(Key)]
    [string]$Name

    [DscProperty()]
    [string]$Version

    [InstallVSExtension] Get()
    {
        # TODO: Currently there is no way to determine which VS extensions are installed.
        return @{
            ProductId = $this.ProductId
            Publisher = $this.Publisher
            Name = $this.Name
            Version = $this.Version
        }
    }

    [bool] Test()
    {
        # Set this to false until there is a way to determine whether a VS extension is installed.
        return $false
    }

    [void] Set()
    {
        Install-VsExtension -ProductId $this.ProductId -Publisher $this.Publisher -Name $this.Name -Version $this.Version
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

# Construct the vsix url and calls setup.exe
function Install-VsExtension
{
    param
    (
        [Parameter(Mandatory)]
        [string]$ProductId,

        [Parameter(Mandatory)]
        [string]$Publisher,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Version
    )

    if ([string]::IsNullOrWhiteSpace($Version))
    {
        $Version = "latest"
    }

    # Construct vsix url.
    $vsixUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$Publisher/vsextensions/$Name/$Version/vspackage"

    try
    {
        $tempName = [System.IO.Path]::GetRandomFileName()
        $tempFilePath = Join-Path -Path $env:TEMP -ChildPath "$tempName.vsix"
        $downloadRequest = Invoke-WebRequest -Uri $vsixUrl -OutFile $tempFilePath
    }
    catch
    {
        throw "Failed to download vsix extension at $vsixUrl with error: $($downloadRequest.StatusCode)"
    }

    $arguments = [List[string]]::new()
    $arguments.Add($tempFilePath)
    # Run quietly
    $arguments.Add("/q")
    # Enable shutdown processes
    $arguments.Add("/sp")

    try
    {
        Invoke-VsixInstaller -ProductId $ProductId -Arguments $arguments
    }
    catch
    {
        # VSIXInstaller will fail if the extension is already installed. Ignore error and proceed.
    }
}

# Required by setup.exe for --passive or --quiet
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

function Invoke-VsixInstaller
{
    param (
        [Parameter(Mandatory)]
        [string]$ProductId,

        [Parameter(Mandatory)]
        [List[string]]$Arguments
    )

    switch ($productId)
    {
        'Microsoft.VisualStudio.Product.Enterprise'
        {
            $product = "Enterprise"
        }
        'Microsoft.VisualStudio.Product.Professional'
        {
            $product = "Professional"
        }
        'Microsoft.VisualStudio.Product.Community'
        {
            $product = "Community"
        }
        default { throw "Visual Studio product does not exist." }
    }

    $vsixInstallerPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\$product\Common7\IDE\vsixinstaller.exe"
    if (-not (Test-Path -Path $vsixInstallerPath))
    {
        throw "VSIXInstaller.exe not found"
    }

    $command = "/c `"$vsixInstallerPath`" " + $Arguments
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList $command -Wait -Passthru -WindowStyle Minimized
    if ($process.ExitCode -ne 0)
    {
        throw "Failed running VSIXInstaller.exe with args $Arguments Error: $($process.ExitCode)"
    }
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
    # Launch cmd and run the setup.exe command. The problem I was seeing is that setup.exe prints the logs in PowerShell
    # but when it completed the control was not given back to powershell at the end of the console and the next Write-Host
    # would end up writing at the top of the window and it just looks weird. Making use of cmd by launching it in another
    # window looks way cleaner.
    $command = "/c `"$vsInstallerPath`" " + $Arguments
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList $command -Wait -PassThru -WindowStyle Minimized
    if ($process.ExitCode -ne 0)
    {
        throw "Failed running setup.exe with args $Arguments Error: $($process.ExitCode)"
    }
}

#endregion Functions
