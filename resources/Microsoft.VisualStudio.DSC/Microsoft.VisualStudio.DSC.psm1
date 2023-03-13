# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic
using namespace System.Diagnostics

#region DSCResources

[DSCResource()]
class VisualStudioComponents
{
    [DscProperty(Key)]
    [string]$productId

    [DscProperty(Key)]
    [string]$channelId

    [DscProperty()]
    [string]$vsconfigFile

    [DscProperty()]
    [string[]]$components

    [DscProperty(NotConfigurable)]
    [string[]]$installedComponents

    [VisualStudioComponents] Get()
    {
        if (-not [string]::IsNullOrEmpty($this.vsconfigFile) -and -not [string]::IsNullOrEmpty($this.components))
        {
            throw "The parameters for vsconfigFile and components cannot both be specified."
        }

        $this.installedComponents = Get-VsComponents -ProductId $this.productId

        return @{
            productId = $this.productId
            channelId = $this.channelId
            vsconfigFile = $this.vsconfigFile
            components = $this.components
            installedComponents = $this.installedComponents
        }       
    }

    [bool] Test()
    {
        # Call get to set the installedComponents property and verify parameters.
        $this.Get()

        if (-not [string]::IsNullOrEmpty($this.vsconfigFile))
        {
            if (-not (Test-Path -Path $this.vsconfigFile))
            {
                throw "vsconfig file does not exist"
            }

            $this.components = Get-Content $this.vsconfigFile | Out-String | ConvertFrom-Json
        }

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

        if (-not [string]::IsNullOrEmpty($this.vsconfigFile))
        {
            Install-VsConfigFile -ProductId $this.productId -ChannelId $this.channelId -vsconfigFile $this.vsconfigFile
        }
        else
        {
            if ([string]::IsNullOrEmpty($this.components))
            {
                throw "No components specified."
            }

            Install-VsComponents -ProductId $this.productId -ChannelId $this.channelId -Components $this.components
        }
    }
}

# VisualStudioExtension installs a vsix extension using setup.exe. We can make it such as it takes the Publisher, Name
# and Version or the URL of the vsix extension (we use the former to construct the URL). If Version is null we use latest.
[DSCResource()]
class VisualStudioExtension
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

    [VisualStudioExtension] Get()
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

# Not used. If we end up having a list of components we can call this, but we need to be careful with how many of them
# are added on the commands. It sounds easiert that this function will create a temporary .vsconfig file and then use that.
function Install-VsComponents
{
    param
    (
        [Parameter(Mandatory)]
        [string]$ProductId,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [List[string]]$Components
    )
    $arguments = [List[string]]::new()
    $arguments.Add("modify")
    $arguments.Add("--productId")
    $arguments.Add($ProductId)
    $arguments.Add("--channelId")
    $arguments.Add($ChannelId)

    foreach ($component in $Components)
    {
        $arguments.Add("--add")
        $arguments.Add($component)
    }

    $arguments.Add("--passive")

    Invoke-VsInstaller -Arguments $arguments
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

    $vsWherePath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
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

    $vsixInstallerPath = "C:\Program Files (x86)\Microsoft Visual Studio\2019\$product\Common7\IDE\vsixinstaller.exe"
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

    $vsInstallerPath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"
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