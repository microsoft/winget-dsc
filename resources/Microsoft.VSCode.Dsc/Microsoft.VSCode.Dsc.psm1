# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#region Functions
function Get-VSCodeCLIPath {
    param (
        [switch]$UseInsiders,
        [string]$CustomPath
    )

    # Currently only supports user/machine install for VSCode on Windows.
    # TODO: Update this function to handle when VSCode is installed in portable mode or on macOS/Linux.

    # If a custom path is provided, use it
    # if ($PSBoundParameters.ContainsKey('CustomPath')) { 
    #     if ((Test-Path -Path $CustomPath) -and (Split-Path $CustomPath -Leaf) -in ('code.cmd', 'code-insiders.cmd')) {
    #         return $CustomPath
    #     } else {
    #         throw "The specified custom path does not exist or does not start with 'code.cmd' or 'code-insiders.cmd'."
    #     }
    # }

    # Determine the paths based on whether the Insiders version is used
    if ($UseInsiders) {
        $codeCLIUserPath = "$env:LocalAppData\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
        $codeCLIMachinePath = "$env:ProgramFiles\Microsoft VS Code Insiders\bin\code-insiders.cmd"
    }
    else {
        $codeCLIUserPath = "$env:LocalAppData\Programs\Microsoft VS Code\bin\code.cmd"
        $codeCLIMachinePath = "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    }

    # Check the paths and return the appropriate one
    if (Test-Path -Path $codeCLIUserPath) {
        return $codeCLIUserPath
    }
    elseif (Test-Path -Path $codeCLIMachinePath) {
        return $codeCLIMachinePath
    }
    else {
        throw "VSCode is not installed."
    }
}

function Install-VSCodeExtension {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [System.String]
        $VSCodeCLIPath = (Get-VSCodeCLIPath)
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
        Invoke-VSCode -Command "--install-extension $installArgument" -VSCodeCLIPath $VSCodeCLIPath
    }
}

function Uninstall-VSCodeExtension {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [System.String]
        $VSCodeCLIPath = (Get-VSCodeCLIPath)
    )
        
    Invoke-VSCode -Command "--uninstall-extension $($this.Name)" -VSCodeCLIPath $VSCodeCLIPath 
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

    [System.Management.Automation.HiddenAttribute()]
    [DscProperty()]
    [System.Boolean]
    $UseInsiders = $false

    static [hashtable] $InstalledExtensions
    
    # VSCodeExtension() {
    #     $this.Initialize($this.UseInsiders)
    #     [VSCodeExtension]::InstalledExtensions = @{}
    # }

    static [void] Initialize([bool]$UseInsiders) {
        [VSCodeExtension]::GetInstalledExtensions($UseInsiders) 
    }

    VSCodeExtension() {
        # [VSCodeExtension]::Initialize($this.UseInsiders)
        [VSCodeExtension]::InstalledExtensions = @{}
    }

    static [VSCodeExtension[]] Export([bool]$UseInsiders) {
        $extensionList = (Invoke-VSCode -Command "--list-extensions --show-versions") -Split [Environment]::NewLine

        $results = [VSCodeExtension[]]::new($extensionList.length)
        
        for ($i = 0; $i -lt $extensionList.length; $i++) {
            $extensionName, $extensionVersion = $extensionList[$i] -Split '@'
            $results[$i] = [VSCodeExtension]@{
                Name    = $extensionName
                Version = $extensionVersion
            }     
        }

        return $results
    }

    [VSCodeExtension] Get() {
        $currentState = [VSCodeExtension]::InstalledExtensions[$this.Name]
        if ($null -ne $currentState) {
            return [VSCodeExtension]::InstalledExtensions[$this.Name]
        }
        
        return [VSCodeExtension]@{
            Name    = $this.Name
            Version = $this.Version
            Exist   = $false
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
    static [void] GetInstalledExtensions([bool]$UseInsiders) {   
        [VSCodeExtension]::InstalledExtensions = @{}

        $script:VSCodeCLIPath = Get-VSCodeCLIPath -UseInsiders:$UseInsiders

        foreach ($extension in [VSCodeExtension]::Export($UseInsiders)) {
            [VSCodeExtension]::InstalledExtensions[$extension.Name] = $extension
        }     
    }

    [void] Install([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        Install-VSCodeExtension -Name $this.Name -Version $this.Version
        [VSCodeExtension]::GetInstalledExtensions()
    }

    [void] Install() {
        $this.Install($true)
    }

    [void] Uninstall([bool] $preTest) {
        Uninstall-VSCodeExtension -Name $this.Name
        [VSCodeExtension]::GetInstalledExtensions()
    }

    [void] Uninstall() {
        $this.Uninstall($true)
    }
    #endregion VSCodeExtension helper functions
}
#endregion DSCResources
