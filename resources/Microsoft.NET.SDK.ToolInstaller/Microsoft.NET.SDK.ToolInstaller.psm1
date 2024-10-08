# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

#region Functions
function Get-DotNetPath
{
    if ($IsWindows)
    {
        $dotNetPath = "$env:ProgramFiles\dotnet\dotnet.exe"
        if (-not (Test-Path $dotNetPath))
        {
            $dotNetPath = "${env:ProgramFiles(x86)}\dotnet\dotnet.exe"
            if (-not (Test-Path $dotNetPath))
            {
                throw "dotnet.exe not found in Program Files or Program Files (x86)"
            }
        }
    }
    elseif ($IsMacOS)
    {
        $dotNetPath = "/usr/local/share/dotnet/dotnet"
        if (-not (Test-Path $dotNetPath))
        {
            $dotNetPath = "/usr/local/bin/dotnet"
            if (-not (Test-Path $dotNetPath))
            {
                throw "dotnet not found in /usr/local/share/dotnet or /usr/local/bin"
            }
        }
    }
    elseif ($IsLinux)
    {
        $dotNetPath = "/usr/share/dotnet/dotnet"
        if (-not (Test-Path $dotNetPath))
        {
            $dotNetPath = "/usr/bin/dotnet"
            if (-not (Test-Path $dotNetPath))
            {
                throw "dotnet not found in /usr/share/dotnet or /usr/bin"
            }
        }
    }
    else
    {
        throw "Unsupported operating system"
    }

    Write-Verbose -Message "'dotnet' found at $dotNetPath"
    return $dotNetPath
}

# TODO: when https://github.com/dotnet/sdk/pull/37394 is documented and version is released with option simple use --format=JSON

function Convert-DotNetToolOutput
{
    [CmdletBinding()]
    param (
        [string[]] $Output
    )

    process
    {
        # Split the output into lines
        $lines = $Output | Select-Object -Skip 2

        # Initialize an array to hold the custom objects
        $inputObject = @()

        # Skip the header lines and process each line
        foreach ($line in $lines)
        {
            # Split the line into columns
            $columns = $line -split '\s{2,}'

            # Create a custom object for each line
            $customObject = [PSCustomObject]@{
                PackageId = $columns[0]
                Version   = $columns[1]
                Commands  = $columns[2]
            }

            # Add the custom object to the array
            $inputObject += $customObject
        }

        return $inputObject
    }
}

function Install-DotNetToolPackage
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Version,
        [Parameter(ValueFromPipelineByPropertyName)]
        [bool] $PreRelease,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ToolPath
    )
    
    begin
    {
        function Get-DotNetToolArguments
        {
            param([string]$Name, [string]$Version, [bool]$PreRelease, [string]$ToolPath)

            $string = $Name
            
            if (-not ([string]::IsNullOrEmpty($Version)))
            {
                $string += " --version $Version"
            }

            if ($PreRelease)
            {
                $string += " --prerelease"
            }

            if ($ToolPath)
            {
                $string += " --tool-path $ToolPath"
            }
            else 
            {
                $string += " --global"
            }

            $string += " --no-cache"

            return $string
        }
    }
    
    process
    {
        $installArgument = Get-DotNetToolArguments @PSBoundParameters
        $arguments = "tool install $installArgument --ignore-failed-sources"
        Write-Verbose -Message "Installing dotnet tool package with arguments: $arguments"

        Invoke-DotNet -Command $arguments
    }
}

function Uninstall-DotNetToolPackage
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name
    )

    $arguments = "tool uninstall $Name --global" 
    Write-Verbose -Message "Uninstalling dotnet tool package with arguments: $arguments"
        
    Invoke-DotNet -Command
}

function Invoke-DotNet
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $Command
    )

    try
    {
        Invoke-Expression "& `"$DotNetCliPath`" $Command"
    }
    catch
    {
        throw "Executing dotnet.exe with {$Command} failed."
    }
}

# Keeps the path of the code.exe CLI path.
$DotNetCliPath = Get-DotNetPath

#endregion Functions

#region Classes
<#
.SYNOPSIS
    This class is used to install and uninstall .NET SDK tools globally or use the tool path directory.
#>
[DSCResource()]
class NETSDKToolInstaller
{
    [DscProperty(Key)]
    [string] $PackageId

    [DscProperty()]
    [string] $Version

    [DscProperty()]
    [string[]] $Commands

    [DscProperty()]
    [bool] $PreRelease = $false

    [DscProperty()]
    [string] $ToolPath

    [DscProperty()]
    [bool] $Exist = $true

    static [hashtable] $InstalledPackages

    NETSDKToolInstaller()
    {
        [NETSDKToolInstaller]::GetInstalledPackages()
    }

    NETSDKToolInstaller([string] $PackageId, [string] $Version, [string[]] $Commands, [bool] $PreRelease, [string] $ToolPath)
    {
        $this.PackageId = $PackageId
        $this.Version = $Version
        $this.Commands = $Commands
        $this.PreRelease = $PreRelease
        $this.ToolPath = $ToolPath
    }

    [NETSDKToolInstaller] Get()
    {
        $properties = $this.ToHashTable()

        $installed = [NETSDKToolInstaller]::Export($properties)

        $currentState = $installed | Where-Object { $_.PackageId -eq $this.PackageId }
        if ($null -ne $currentState)
        {
            # update the export list
            $currentState::InstalledPackages[$this.PackageId] = $currentState
            return $currentState
        }
        
        return [NETSDKToolInstaller]@{
            PackageId = $this.PackageId
            Version   = $this.Version
            Commands  = $this.Commands
            Exist     = $false
        }
    }

    Set()
    {
        # TODO: validate for upgrade/update scenarios
        if ($this.Test())
        {
            return
        }

        if ($this.Exist)
        {
            $this.Install($false)
        }
        else
        {
            $this.Uninstall($false)
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        if ($currentState.Exist -ne $this.Exist)
        {
            return $false
        }

        if ($null -ne $this.Version -and $this.Version -ne $currentState.Version)
        {
            return $false
        }

        return $true
    }

    static [NETSDKToolInstaller[]] Export()
    {
        return [NETSDKToolInstaller]::Export(@{})
    }

    static [NETSDKToolInstaller[]] Export([hashtable] $filterProperties)
    {
        $command = "tool list --global"
        
        $toolsDir = $filterProperties.ContainsKey("ToolPath")
        if ($toolsDir)
        {
            $command = "tool list --tool-path $($filterProperties.ToolPath)"
        }
 
        $packageList = Invoke-DotNet -Command $command

        $inputObject = Convert-DotNetToolOutput -Output $packageList

        $results = [List[NETSDKToolInstaller]]::new()

        foreach ($package in $inputObject)
        {
            # determine if the package is a pre-release package
            $pre = $false
            $preReleasePackage = $package.Version -Split "-"
            if ($preReleasePackage.Count -gt 1)
            {
                # set the pre-release flag to true to build the object
                $pre = $true
            }

            # default directory
            $defaultDir = " "
            if ($toolsDir)
            {
                # TODO: How are we going to handle if tool path was not set? Should exist be false?
                $package.Commands | Foreach-Object {
                    $customPaths = @(
                        Join-Path $filterProperties.ToolPath "$_.exe"
                        Join-Path -Path $env:USERPROFILE '.dotnet' 'tools' "$_.exe"
                    )
    
                    foreach ($path in $customPaths)
                    {
                        if (Test-Path $path)
                        {
                            $defaultDir = (Split-Path $path)
                            break
                        }
                        else 
                        {
                            $defaultDir = $null
                        }
                    }
                }
            }

            $results.Add([NETSDKToolInstaller]::new(
                    $package.PackageId, $package.Version, $package.Commands, $pre, $defaultDir
                ))
        }

        return $results
    }

    #region NETSDKToolInstaller helper functions
    static [void] GetInstalledPackages()
    {   
        [NETSDKToolInstaller]::InstalledPackages = @{}

        foreach ($extension in [NETSDKToolInstaller]::Export())
        {
            [NETSDKToolInstaller]::InstalledPackages[$extension.PackageId] = $extension
        }
    }

    [void] Install([bool] $preTest)
    {
        if ($preTest -and $this.Test())
        {
            return
        }

        Install-DotNetToolpackage -Name $this.PackageId -Version $this.Version -PreRelease $this.PreRelease -ToolPath $this.ToolPath
        [NETSDKToolInstaller]::GetInstalledPackages()
    }

    [void] Install()
    {
        $this.Install($true)
    }

    [void] Uninstall([bool] $preTest)
    {
        Uninstall-DotNetToolpackage -Name $this.PackageId
        [NETSDKToolInstaller]::GetInstalledPackages()
    }

    [void] Uninstall()
    {
        $this.Uninstall($true)
    }

    [hashtable] ToHashTable()
    {
        $parameters = @{}
        foreach ($property in $this.PSObject.Properties)
        {
            $parameters[$property.Name] = $property.Value
        }

        return $parameters
    }
    #endregion NETSDKToolInstaller helper functions
}
#
#endregion Classesendregion Classes
