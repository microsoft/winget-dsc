# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

#region Functions
function Get-VSCodeRegistryKey {
    [CmdletBinding()]
    param (
        [string] $Architecture
    )

    switch ($architecture) {
        'X64' { return @('{771FD6B0-FA20-440A-A002-3B3BAC16DC50}_is1', '{EA457B21-F73E-494C-ACAB-524FDE069978}_is1') }
        'X86' { return @('{D628A17A-9713-46BF-8D57-E671B46A741E}_is1', '{F8A2A208-72B3-4D61-95FC-8A65D340689B}_is1') }
        'Arm64' { return @('{D9E514E7-1A56-452D-9337-2990C0DC4310}_is1', '{A5270FC5-65AD-483E-AC30-2C276B63D0AC}_is1') }
        default { throw 'Could not determine architecture.' }
    }
}

function Get-VSCodeInsidersRegistryKey {
    param (
        [string] $Architecture
    )

    switch ($Architecture) {
        'X64' { return @('{217B4C08-948D-4276-BFBB-BEE930AE5A2C}_is1', '{1287CAD5-7C8D-410D-88B9-0D1EE4A83FF2}_is1') }
        'X86' { return @('{C26E74D1-022E-4238-8B9D-1E7564A36CC9}_is1', '{26F4A15E-E392-4887-8C09-7BC55712FD5B}_is1') }
        'Arm64' { return @('{69BD8F7B-65EB-4C6F-A14E-44CFA83712C0}_is1', '{0AEDB616-9614-463B-97D7-119DD86CCA64}_is1') }
        default { throw 'Could not determine architecture.' }
    }
}

function Get-OSArchitectureRegistryKey {
    [CmdletBinding()]
    param (
        [ValidateSet('X64', 'X86', 'Arm64')]
        [string] $Architecture,
        [switch] $Insiders
    )

    $registryKey = if ($Insiders.IsPresent) {
        Get-VSCodeInsidersRegistryKey -Architecture $architecture
    } else {
        Get-VSCodeRegistryKey -Architecture $architecture
    }

    return $registryKey
}

function Get-VSCodeCLIPath {
    param (
        [switch]$Insiders
    )

    $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    # Get the available keys
    $registryKeys = Get-OSArchitectureRegistryKey -Insiders:$Insiders.IsPresent -Architecture $architecture
    $registryHive = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')

    if ($IsLinux) {
        $command = 'code'
        if ($Insiders.IsPresent) {
            $command = 'code-insiders'
        }
        # Using Get-Command to find the path of the command instead of PATH environment variable because both can be installed
        $commandPath = Get-Command -Name $command -ErrorAction SilentlyContinue
        if ($commandPath) {
            return $commandPath.Source
        }
    }

    if ($IsWindows) {
        foreach ($hive in $registryHive) {
            foreach ($key in $registryKeys) {
                Write-Verbose -Message ("Searching path '{0}' with key '{1}'" -f $hive, $key)
                $installLocation = TryGetRegistryValue -Key "$hive\$key" -Property 'InstallLocation'
                if ($installLocation) {
                    $cmdPath = $Insiders ? 'bin\code-insiders.cmd' : 'bin\code.cmd'
                    return Join-Path $installLocation $cmdPath
                }
            }
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
        [string]$Version,

        [Parameter()]
        [bool]$PreRelease
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
        # Always add the --force parameter to support switching between release and prerelease version
        $command = "--install-extension $installArgument --force"

        if ($PreRelease) {
            $command += ' --pre-release'
        }

        Invoke-VSCode -Command $command
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
    $invocationErrors = $invocationErrors -replace '\n', '\n '
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

function Get-PreReleaseFlag {
    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        [string] $Name,

        [Parameter()]
        [AllowNull()]
        [string] $Version,

        [Parameter()]
        [switch] $Insiders
    )

    if ($IsWindows) {
        $packageName = [System.String]::Concat($Name, '-', $Version)
        if ($Insiders) {
            $extensionPath = Join-Path $env:USERPROFILE '.vscode-insiders' 'extensions' $packageName '.vsixmanifest'
        } else {
            $extensionPath = Join-Path $env:USERPROFILE '.vscode' 'extensions' $packageName '.vsixmanifest'
        }

        if (Test-Path $extensionPath -ErrorAction SilentlyContinue) {
            [xml]$manifest = Get-Content $extensionPath -ErrorAction SilentlyContinue
            # If it does not contain the property, it is not a pre-release extension
            if ($manifest.PackageManifest.Metadata.Properties.Property.Id -contains 'Microsoft.VisualStudio.Code.PreRelease') {
                return $true
            } else {
                return $false
            }
        }
    }
}

function Get-VsixManifestInfo {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    [System.IO.Compression.ZipFile]::OpenRead($Path) | ForEach-Object {
        $zipArchive = $_

        $zipEntry = $zipArchive.Entries | Where-Object { $_.FullName -eq 'extension.vsixmanifest' }

        if ($zipEntry) {
            $reader = [System.IO.StreamReader]::new($zipEntry.Open())
            [xml]$fileContent = $reader.ReadToEnd()
            $reader.Close()

            $packageId = [System.String]::Concat($fileContent.PackageManifest.Metadata.Identity.Publisher, '.', $fileContent.PackageManifest.Metadata.Identity.Id)
            return @{
                Name       = $packageId
                Version    = $fileContent.PackageManifest.Metadata.Identity.Version
                PreRelease = ($fileContent.PackageManifest.Metadata.Properties.Property.Id -contains 'Microsoft.VisualStudio.Code.PreRelease')
            }
        } else {
            throw "VSIX manifest not found. Ensure the VSIX file contains a 'extension.vsixmanifest' file."
        }

        # Close the zip archive
        $zipArchive.Dispose()
    }
}

function Test-VsixFilePath {
    param (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string] $InputString
    )

    $extension = [System.IO.Path]::GetExtension($InputString)

    if ($extension -eq '.vsix') {
        if (Test-Path -Path $InputString -ErrorAction SilentlyContinue) {
            return $true
        } else {
            return $false
        }
    } else {
        return $false
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

.PARAMETER PreRelease
    Indicates whether to install the pre-release version of the extension. The default value is `$false`.

    When PreRelease is set to `$true`, the extension will be installed from the Visual Studio Code marketplace. If the extension is already installed, it will be updated to the pre-release version.
    If there is no prerelease version available, the extension will be installed.

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

.EXAMPLE
    PS C:\> $params = @{
        Name = 'dbaeumer.vscode-eslint'
        PreRelease = $true
    }
    PS C:\> Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc

    This installs the latest pre-release version of the Visual Studio Code extension 'dbaeumer.vscode-eslint'

.EXAMPLE
    PS C:\> $params = @{
        Name = 'C:\SharedExtensions\ms-python.python-2021.5.842923320.vsix'
    }
    PS C:\> Invoke-DscResource -Name VSCodeExtension -Method Set -Property $params -ModuleName Microsoft.VSCode.Dsc

    This installs the Visual Studio Code extension 'ms-python.python' from the specified VSIX file path.
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
    [bool] $PreRelease = $false

    [DscProperty()]
    [bool] $Insiders = $false

    static [hashtable] $InstalledExtensions

    VSCodeExtension() {
    }

    VSCodeExtension([string]$Name, [string]$Version) {
        $this.Name = $Name
        $this.Version = $Version
    }

    VSCodeExtension([string]$Name, [string]$Version, [bool]$Insiders) {
        $this.Name = $Name
        $this.Version = $Version
        $this.Insiders = $Insiders
    }

    [VSCodeExtension[]] Export([bool]$Insiders) {
        if ($Insiders) {
            $script:VSCodeCLIPath = Get-VSCodeCLIPath -Insiders
        } else {
            $script:VSCodeCLIPath = Get-VSCodeCLIPath
        }

        $extensionList = (Invoke-VSCode -Command '--list-extensions --show-versions') -split [Environment]::NewLine

        $results = [VSCodeExtension[]]::new($extensionList.length)

        for ($i = 0; $i -lt $extensionList.length; $i++) {
            $extensionName, $extensionVersion = $extensionList[$i] -split '@'
            $initialize = @{
                Name       = $extensionName
                Version    = $extensionVersion
                PreRelease = (Get-PreReleaseFlag -Name $extensionName -Version $extensionVersion -Insiders:$Insiders)
            }

            if ($Insiders) {
                $initialize.Insiders = $true
            }

            $results[$i] = [VSCodeExtension]$initialize
        }

        return $results
    }

    [VSCodeExtension] Get() {
        if (Test-VsixFilePath -InputString $this.Name) {
            $manifestInfo = Get-VsixManifestInfo -Path $this.Name
            $this.Name = $manifestInfo.Name
            $this.Version = $manifestInfo.Version
            $this.PreRelease = $manifestInfo.PreRelease
        }

        [VSCodeExtension]::GetInstalledExtensions($this.Insiders)

        $currentState = [VSCodeExtension]::InstalledExtensions[$this.Name]
        if ($null -ne $currentState) {
            if ($null -ne $this.Version) {
                $versionState = $currentState | Where-Object { $_.Version -eq $this.Version }
                if ($versionState) {
                    $finalState = [VSCodeExtension]::InstalledExtensions[$this.Name]
                } else {
                    $currentState.Exist = $false
                    $finalState = $currentState
                }
            } else {
                $finalState = [VSCodeExtension]::InstalledExtensions[$this.Name]
            }

            if ($currentState.PreRelease -ne $this.PreRelease) {
                $currentState.Exist = $false
                $finalState = $currentState
            }

            return $finalState
        }
        Write-Verbose -Message "Extension '$($this.Name)' with version '$($this.Version)' and pre-release '$($this.PreRelease)' does not exist." -Verbose
        return [VSCodeExtension]@{
            Name       = $this.Name
            Version    = $this.Version
            Exist      = $false
            PreRelease = $this.PreRelease
            Insiders   = $this.Insiders
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

        if ($null -ne $this.PreRelease -and $this.PreRelease -ne $currentState.PreRelease) {
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

        Install-VSCodeExtension -Name $this.Name -Version $this.Version -PreRelease $this.PreRelease
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
