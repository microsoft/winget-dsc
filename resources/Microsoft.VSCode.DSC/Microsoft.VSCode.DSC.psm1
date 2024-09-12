# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#region Enums
enum VSCodeEnsure
{
    Absent
    Present
}
#endregion Enums

#region Functions
function Get-VSCodeCLIPath
{
    $codeCLIUserPath = "$env:LocalAppData\Programs\Microsoft VS Code\bin\code.cmd"
    $codeCLIMachinePath = "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"

    if (Test-Path -Path $codeCLIUserPath)
    {
        return $codeCLIUserPath
    }
    elseif (Test-Path -Path $codeCLIMachinePath)
    {
        return $codeCLIMachinePath
    }
    else
    {
        throw "VSCode is not installed."
    }
}

function Install-VSCodeExtension
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Version
    )
    
    begin
    {
        function Get-VSCodeExtensionInstallArgument
        {
            param([string]$Name, [string]$Version)
            
            if ([string]::IsNullOrEmpty($Version))
            {
                return $Name
            }

            return @(
                $Name
                $Version
            ) -join '@'
        }
    }
    
    process
    {
        $installArgument = Get-VSCodeExtensionInstallArgument @PSBoundParameters
        Invoke-VSCode -Command "--install-extension $installArgument"
    }
}

function Uninstall-VSCodeExtension
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name
    )
        
    Invoke-VSCode -Command "--uninstall-extension $($this.Name)"  
}

function Invoke-VSCode
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    try 
    {
        Invoke-Expression "& `"$VSCodeCLIPath`" $Command"
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    }
    catch
    {
        throw "Executing code.exe with {$Command} failed."
    }
}
#endregion Functions

# Keeps the path of the code.exe CLI path.
$VSCodeCLIPath = Get-VSCodeCLIPath

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

    static [hashtable] $InstalledExtensions

    static VSCodeExtension()
    {
        [VSCodeExtension]::GetInstalledExtensions()
    }

    static [VSCodeExtension[]] Export()
    {
        $extensionList = (Invoke-VSCode -Command "--list-extensions --show-versions") -Split [Environment]::NewLine

        $results = [VSCodeExtension[]]::new($extensionList.length)
        
        for ($i = 0; $i -lt $extensionList.length; $i++)
        {
            $extensionName, $extensionVersion = $extensionList[$i] -Split '@'
            $results[$i] = [VSCodeExtension]@{
                Name = $extensionName
                Version = $extensionVersion
            }     
        }

        return $results
    }

    [VSCodeExtension] Get()
    {
        $currentState = [VSCodeExtension]::InstalledExtensions[$this.Name]
        if ($null -ne $currentState)
        {
            return $currentState
        }
        
        return [VSCodeExtension]@{
            Name = $this.Name
            Version = $this.Version
            Ensure = [VSCodeEnsure]::Absent
        }
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
            $this.Install($false)
        }
        else
        {
            $this.Uninstall($false)
        }
    }

#region VSCodeExtension helper functions
    static [void] GetInstalledExtensions()
    {
        [VSCodeExtension]::InstalledExtensions = @{}
        foreach ($extension in [VSCodeExtension]::Export())
        {
            [VSCodeExtension]::InstalledExtensions[$extension.Name] = $extension
        }          
    }

    [void] Install([bool] $preTest)
    {
        if ($preTest -and $this.Test())
        {
            return
        }

        Install-VSCodeExtension -Name $this.Name -Version $this.Version
        [VSCodeExtension]::GetInstalledExtensions()
    }

    [void] Install()
    {
        $this.Install($true)
    }

    [void] Uninstall([bool] $preTest)
    {
        Uninstall-VSCodeExtension -Name $this.Name
        [VSCodeExtension]::GetInstalledExtensions()
    }

    [void] Uninstall()
    {
        $this.Uninstall($true)
    }
#endregion VSCodeExtension helper functions
}
#endregion DSCResources
