# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

#region Functions
function Get-VSCodeCLIPath {
    param (
        [switch]$Insiders
    )

    # Product Codes for VSCode and VSCode Insider:
    $vsCodeUserProductCode = '{771FD6B0-FA20-440A-A002-3B3BAC16DC50}_is1'
    $vsCodeMachineProductCode = '{EA457B21-F73E-494C-ACAB-524FDE069978}_is1'

    $vsCodeInsidersUserProductCode = '{217B4C08-948D-4276-BFBB-BEE930AE5A2C}_is1'
    $vsCodeInsidersMachineProductCode = '{1287CAD5-7C8D-410D-88B9-0D1EE4A83FF2}_is1'

    # Note: WOW6432 registry not checked as no uninstall entry was found.
    $userUninstallRegistry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $machineUninstallRegistry = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $installLocationProperty = 'InstallLocation'

    if ($Insiders) {
        $cmdPath = 'bin\code-insiders.cmd'
        $insidersUserInstallLocation = TryGetRegistryValue -Key "$($userUninstallRegistry)\$($vsCodeInsidersUserProductCode)" -Property $installLocationProperty
        if ($insidersUserInstallLocation) {
            return $insidersUserInstallLocation + $cmdPath
        }

        $insidersMachineInstallLocation = TryGetRegistryValue -Key "$($machineUninstallRegistry)\$($vsCodeInsidersMachineProductCode)" -Property $installLocationProperty
        if ($insidersMachineInstallLocation) {
            return $insidersMachineInstallLocation + $cmdPath
        }
    } else {
        $cmdPath = 'bin\code.cmd'
        $codeUserInstallLocation = TryGetRegistryValue -Key "$($userUninstallRegistry)\$($vsCodeUserProductCode)" -Property $installLocationProperty
        if ($codeUserInstallLocation) {
            return $codeUserInstallLocation + $cmdPath
        }

        $codeMachineInstallLocation = TryGetRegistryValue -Key "$($machineUninstallRegistry)\$($vsCodeMachineProductCode)" -Property $installLocationProperty
        if ($codeMachineInstallLocation) {
            return $codeMachineInstallLocation + $cmdPath
        }
    }

    throw 'VSCode is not installed.'
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

    $stdErrTempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (New-Guid).Guid
    $stdOutTempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (New-Guid).Guid
    $invocationSuccess = $true

    $processParams = @{
        FilePath               = $VSCodeCLIPath
        ArgumentList           = "$Command"
        RedirectStandardError  = $stdErrTempFile
        RedirectStandardOutput = $stdOutTempFile
        Wait                   = $true
        PassThru               = $true
        NoNewWindow            = $true
    }

    $invocation = Start-Process @processParams
    $invocationErrors = Get-Content $stdErrTempFile -Raw -ErrorAction SilentlyContinue
    $invocationErrors = $invocationErrors -Replace '\n', '\n '
    $invocationOutput = Get-Content $stdOutTempFile -ErrorAction SilentlyContinue
    Remove-Item -Path $stdErrTempFile -ErrorAction Ignore
    Remove-Item -Path $stdOutTempFile -ErrorAction Ignore

    if (![string]::IsNullOrWhiteSpace($invocationErrors)) { $invocationSuccess = $false }
    if ($invocation.ExitCode) { $invocationSuccess = $false }
    if (!$invocationSuccess) { throw [System.Configuration.ConfigurationException]::new("Executing '$VSCodeCLIPath $Command' failed. Command Output: '$invocationErrors'") }

    return $invocationOutput
}

function TryGetRegistryValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Property
    )

    if (Test-Path -Path $Key) {
        try {
            return (Get-ItemProperty -Path $Key | Select-Object -ExpandProperty $Property)
        } catch {
            Write-Verbose "Property `"$($Property)`" could not be found."
        }
    } else {
        Write-Verbose 'Registry key does not exist.'
    }
}
#endregion Functions

#region DSCResources
<#
.SYNOPSIS
    The `VSCodeExtension` DSC Resource allows you to install, update, and remove Visual Studio Code extensions. This resource ensures that the specified Visual Studio Code extension is in the desired state.

.PARAMETER Name
    The name of the Visual Studio Code extension to manage. This is a required parameter.

.PARAMETER Version
    The version of the Visual Studio Code extension to install. If not specified, the latest version will be installed.

.PARAMETER Exist
    Indicates whether the extension should exist. The default value is `$true`.

.PARAMETER Insiders
    Indicates whether to manage the extension for the Insiders version of Visual Studio Code. The default value is `$false`.

.EXAMPLE
    PS C:\> $params = @{
        Name = 'ms-python.python'
    }
    PS C:\> Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc

    This installs the latest version of the Visual Studio Code extension 'ms-python.python'

.EXAMPLE
    # Install a specific version of the Visual Studio Code extension 'ms-python.python'
    PS C:\> $params = @{
        Name = 'ms-python.python'
        Version = '2021.5.842923320'
    }
    PS C:\> Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc

    This installs a specific version of the Visual Studio Code extension 'ms-python.python'

.EXAMPLE
    PS C:\> $params = @{
        Name = 'ms-python.python'
        Exist = $false
    }
    PS C:\> Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc

    This removes the Visual Studio Code extension 'ms-python.python'

.EXAMPLE
    PS C:\> $params = @{
        Name = 'ms-python.python'
        Insiders = $true
    }
    PS C:\> Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc

    This installs the latest version of the Visual Studio Code extension 'ms-python.python' for the Insiders version of Visual Studio Code
#>
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

    [VSCodeExtension[]] Export([bool]$Insiders) {
        if ($Insiders) {
            $script:VSCodeCLIPath = Get-VSCodeCLIPath -Insiders
        } else {
            $script:VSCodeCLIPath = Get-VSCodeCLIPath
        }

        $extensionList = (Invoke-VSCode -Command '--list-extensions --show-versions') -Split [Environment]::NewLine

        $results = [VSCodeExtension[]]::new($extensionList.length)

        for ($i = 0; $i -lt $extensionList.length; $i++) {
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
            Name     = $this.Name
            Version  = $this.Version
            Exist    = $false
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
        } else {
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
