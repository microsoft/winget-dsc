# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#region Functions
function Get-VSCodeCLIPath {
    param (
        [switch]$Insiders
    )

    $userUninstallRegistry = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    $machineUninstallRegistry = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    $installLocationProperty = "InstallLocation"

    if ($Insiders)
    {
        $cmdPath = "bin\code-insiders.cmd"
        $insidersUserInstallLocation = TryGetRegistryValue -Key "$($userUninstallRegistry)\{217B4C08-948D-4276-BFBB-BEE930AE5A2C}_is1" -Property $installLocationProperty
        if ($insidersUserInstallLocation)
        {
            return $insidersUserInstallLocation + $cmdPath
        }

        $insidersMachineInstallLocation = TryGetRegistryValue -Key "$($machineUninstallRegistry)\{1287CAD5-7C8D-410D-88B9-0D1EE4A83FF2}_is1" -Property $installLocationProperty
        if ($insidersMachineInstallLocation)
        {
            return $insidersMachineInstallLocation + $cmdPath
        }
    }
    else
    {
        $cmdPath = "bin\code.cmd"
        $codeUserInstallLocation = TryGetRegistryValue -Key "$($userUninstallRegistry)\{771FD6B0-FA20-440A-A002-3B3BAC16DC50}_is1" -Property $installLocationProperty
        if ($codeUserInstallLocation)
        {
            return $codeUserInstallLocation + $cmdPath
        }

        $codeMachineInstallLocation = TryGetRegistryValue -Key "$($machineUninstallRegistry)\{EA457B21-F73E-494C-ACAB-524FDE069978}_is1" -Property $installLocationProperty
        if ($codeMachineInstallLocation)
        {
            return $codeMachineInstallLocation + $cmdPath
        }
    }

    throw "VSCode is not installed."
}

function Install-VSCodeExtension {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Version
    )
    
    begin {
        function Get-VSCodeExtensionInstallArgument {
            param([string]$Name, [string]$Version)
            
            if ([string]::IsNullOrEmpty($Version)) {
                return $Name
            }

            return @(
                $Name
                $Version
            ) -join '@'
        }
    }
    
    process {
        $installArgument = Get-VSCodeExtensionInstallArgument @PSBoundParameters
        Invoke-VSCode -Command "--install-extension $installArgument"
    }
}

function Uninstall-VSCodeExtension {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name
    )
        
    Invoke-VSCode -Command "--uninstall-extension $($this.Name)"
}

function Invoke-VSCode {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    try {
        Invoke-Expression "& `"$VSCodeCLIPath`" $Command"
    }
    catch {
        throw ("Executing {0} with {$Command} failed." -f $VSCodeCLIPath)
    }
}

function TryGetRegistryValue{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Property
        )    

    if (Test-Path -Path $Key)
    {
        try
        {
            return (Get-ItemProperty -Path $Key | Select-Object -ExpandProperty $Property)     
        }
        catch
        {
            Write-Verbose "Property `"$($Property)`" could not be found."
        }
    }
    else
    {
        Write-Verbose "Registry key does not exist."
    }
}
#endregion Functions

#region DSCResources
[DSCResource()]
class VSCodeExtension {
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [string] $Version

    [DscProperty()]
    [bool] $Exist = $true

    [DscProperty()]
    [bool] $Insiders = $false

    static [hashtable] $InstalledExtensions

    VSCodeExtension() {
    }

    VSCodeExtension([string]$Name, [string]$Version) {
        $this.Name = $Name
        $this.Version = $Version
    }

    [VSCodeExtension[]] Export([bool]$Insiders)
    {
        if ($Insiders) {
            $script:VSCodeCLIPath = Get-VSCodeCLIPath -Insiders
        }
        else {
            $script:VSCodeCLIPath = Get-VSCodeCLIPath
        }

        $extensionList = (Invoke-VSCode -Command "--list-extensions --show-versions") -Split [Environment]::NewLine

        $results = [VSCodeExtension[]]::new($extensionList.length)
        
        for ($i = 0; $i -lt $extensionList.length; $i++)
        {
            $extensionName, $extensionVersion = $extensionList[$i] -Split '@'
            $results[$i] = [VSCodeExtension]::new($extensionName, $extensionVersion)
        }

        return $results
    }

    [VSCodeExtension] Get() {
        [VSCodeExtension]::GetInstalledExtensions($this.Insiders)

        $currentState = [VSCodeExtension]::InstalledExtensions[$this.Name]
        if ($null -ne $currentState) {
            return [VSCodeExtension]::InstalledExtensions[$this.Name]
        }
        
        return [VSCodeExtension]@{
            Name    = $this.Name
            Version = $this.Version
            Exist   = $false
            Insiders = $this.Insiders
        }
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($currentState.Exist -ne $this.Exist) {
            return $false
        }

        if ($null -ne $this.Version -and $this.Version -ne $currentState.Version) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        if ($this.Exist) {
            $this.Install($false)
        }
        else {
            $this.Uninstall($false)
        }
    }

#region VSCodeExtension helper functions
    static [void] GetInstalledExtensions([bool]$Insiders) {   
        [VSCodeExtension]::InstalledExtensions = @{}

        $extension = [VSCodeExtension]::new()

        foreach ($extension in $extension.Export($Insiders)) {
            [VSCodeExtension]::InstalledExtensions[$extension.Name] = $extension
        }
    }

    [void] Install([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        Install-VSCodeExtension -Name $this.Name -Version $this.Version
        [VSCodeExtension]::GetInstalledExtensions($this.Insiders)
    }

    [void] Install() {
        $this.Install($true)
    }

    [void] Uninstall([bool] $preTest) {
        Uninstall-VSCodeExtension -Name $this.Name
        [VSCodeExtension]::GetInstalledExtensions($this.Insiders)
    }

    [void] Uninstall() {
        $this.Uninstall($true)
    }
#endregion VSCodeExtension helper functions
}
#endregion DSCResources
