using namespace System.Collections.Generic
#Region '.\Enum\Ensure.ps1' 0
enum Ensure
{
    Absent
    Present
}
#EndRegion '.\Enum\Ensure.ps1' 6
#Region '.\Classes\DSCResources\NpmInstall.ps1' 0
#using namespace System.Collections.Generic
[DSCResource()]
class NpmInstall
{
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$SID

    [DscProperty()]
    [bool]$Global

    [DscProperty()]
    [string]$PackageDirectory

    [DscProperty()]
    [string]$Arguments

    [NpmInstall] Get()
    {
        Assert-Npm

        if (-not([string]::IsNullOrEmpty($this.PackageDirectory)))
        {
            Set-PackageDirectory -PackageDirectory $this.PackageDirectory
        }

        $currentState = [NpmInstall]::new()
        $currentState.Ensure = [Ensure]::Present

        $errorResult = Get-InstalledNpmPackages -Global $this.Global | ConvertFrom-Json | Select-Object -ExpandProperty error
        if ($errorResult.PSobject.Properties.Name -contains 'code')
        {
            $errorCode = $errorResult | Select-Object -ExpandProperty code
            if ($errorCode -eq 'ELSPROBLEMS')
            {
                $currentState.Ensure = [Ensure]::Absent
            }
        }

        $currentState.Global = $this.Global
        $currentstate.PackageDirectory = $this.PackageDirectory
        $currentState.Arguments = $this.Arguments
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $this.Ensure -eq $currentState.Ensure
    }

    [void] Set()
    {
        $inDesiredState = $this.Test()
        if ($this.Ensure -eq [Ensure]::Present)
        {
            if (-not $inDesiredState)
            {
                Install-NpmPackage -Arguments $this.Arguments -Global $this.Global
            }
        }
        else
        {
            if (-not $inDesiredState)
            {
                $nodeModulesFolder = 'node_modules'
                if (Test-Path -Path $nodeModulesFolder)
                {
                    Remove-Item $nodeModulesFolder -Recurse
                }
            }
        }
    }
}
#EndRegion '.\Classes\DSCResources\NpmInstall.ps1' 77
#Region '.\Classes\DSCResources\NpmPackage.ps1' 0
[DSCResource()]
class NpmPackage
{
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$Name

    [DscProperty()]
    [string]$Version

    [DscProperty()]
    [string]$PackageDirectory

    [DscProperty()]
    [bool]$Global

    [DscProperty()]
    [string]$Arguments

    [NpmPackage] Get()
    {
        Assert-Npm

        if (-not([string]::IsNullOrEmpty($this.PackageDirectory)))
        {
            Set-PackageDirectory -PackageDirectory $this.PackageDirectory
        }

        $currentState = [NpmPackage]::new()
        $currentState.Ensure = [Ensure]::Absent

        $installedPackages = Get-InstalledNpmPackages -Global $this.Global | ConvertFrom-Json | Select-Object -ExpandProperty dependencies
        if ($installedPackages.PSobject.Properties.Name -contains $this.Name)
        {
            $installedPackage = $installedPackages | Select-Object -ExpandProperty $this.Name

            # Check if version matches if specified.
            if (-not([string]::IsNullOrEmpty($this.Version)))
            {
                $installedVersion = $installedPackage.Version
                if ([System.Version]$installedVersion -eq [System.Version]$this.Version)
                {
                    $currentState.Ensure = [Ensure]::Present
                }
            }
            else
            {
                $currentState.Ensure = [Ensure]::Present
            }
        }

        $currentState.Name = $this.Name
        $currentState.Version = $this.Version
        $currentState.Global = $this.Global
        $currentState.Arguments = $this.Arguments
        $currentState.PackageDirectory = $this.PackageDirectory
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $this.Ensure -eq $currentState.Ensure
    }

    [void] Set()
    {
        $inDesiredState = $this.Test()
        if ($this.Ensure -eq [Ensure]::Present)
        {
            if (-not $inDesiredState)
            {
                Install-NpmPackage -PackageName $this.Name -Arguments $this.Arguments -Global $this.Global
            }
        }
        else
        {
            if (-not $inDesiredState)
            {
                Uninstall-NpmPackage -PackageName $this.Name -Arguments $this.Arguments -Global $this.Global
            }
        }
    }
}
#EndRegion '.\Classes\DSCResources\NpmPackage.ps1' 87
#Region '.\Private\Assert-Npm.ps1' 0
function Assert-Npm
{
    # Refresh session $path value before invoking 'npm'
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    try
    {
        Invoke-Npm -Command 'help'
        return
    }
    catch
    {
        throw "NodeJS is not installed"
    }
}
#EndRegion '.\Private\Assert-Npm.ps1' 15
#Region '.\Private\Invoke-Npm.ps1' 0
function Invoke-Npm
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return Invoke-Expression -Command "npm $Command"
}
#EndRegion '.\Private\Invoke-Npm.ps1' 10
#Region '.\Private\Set-PackageDirectory.ps1' 0
function Set-PackageDirectory
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageDirectory
    )

    if (Test-Path -Path $PackageDirectory -PathType Container)
    {
        Set-Location -Path $PackageDirectory
    }
    else
    {
        throw "$($PackageDirectory) does not point to a valid directory."
    }
}
#EndRegion '.\Private\Set-PackageDirectory.ps1' 17
#Region '.\Public\Get-InstalledNpmPackages.ps1' 0
function Get-InstalledNpmPackages
{
    param (
        [Parameter()]
        [bool]$Global
    )

    $command = [List[string]]::new()
    $command.Add('list')
    $command.Add('--json')

    if ($Global)
    {
        $command.Add('-g')
    }

    return Invoke-Npm -command $command
}
#EndRegion '.\Public\Get-InstalledNpmPackages.ps1' 19
#Region '.\Public\Install-NpmPackage.ps1' 0
function Install-NpmPackage
{
    param (
        [Parameter()]
        [string]$PackageName,

        [Parameter()]
        [bool]$Global,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add("install")
    $command.Add($PackageName)

    if ($Global)
    {
        $command.Add("-g")
    }

    $command.Add($Arguments)

    return Invoke-Npm -command $command
}
#EndRegion '.\Public\Install-NpmPackage.ps1' 27
#Region '.\Public\Uninstall-NpmPackage.ps1' 0
function Uninstall-NpmPackage
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter()]
        [bool]$Global,

        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add("uninstall")
    $command.Add($PackageName)

    if ($Global)
    {
        $command.Add('-g')
    }

    $command.Add($Arguments)

    return Invoke-Npm -command $command
}
#EndRegion '.\Public\Uninstall-NpmPackage.ps1' 27

