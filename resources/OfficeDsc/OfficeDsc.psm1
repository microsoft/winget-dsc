# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrEmpty($env:TestRegistryPath)) {
    $global:OfficeRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
    
} else {
    $global:OfficeRegistryPath = $env:TestRegistryPath
}

#region Enums
enum ProductId {
    O365ProPlusEEANoTeamsRetail      # Microsoft 365 Apps for enterprise
    O365ProPlusRetail                # Office 365 Enterprise E3, E5, Microsoft 365 E3, E5, Office 365 E3, E5
    O365BusinessEEANoTeamsRetail     # Microsoft 365 Apps for business
    O365BusinessRetail               # Microsoft 365 Business Standard, Business Premium
}

enum PackageId {
    Access 
    Excel
    Groove
    Lync
    OneDrive
    OneNote
    Outlook
    OutlookForWindows
    PowerPoint
    Publisher
    Teams
    Word
}
#endregion Enums

#region Functions
function Get-OfficeInstallation ($ProductId) {
    $keyPresent = TryGetRegistryValue -Key $global:OfficeRegistryPath -Property 'InstallationPath'
    $installed = $false
    if ($null -ne $keyPresent) {
        $installed = Test-Path -Path $keyPresent -ErrorAction Ignore
    }

    $searchProperty = [System.String]::Concat($ProductId, '.ExcludedApps')

    Write-Verbose -Message "Searching for excluded apps with property name: '$searchProperty'"
    $excludedApps = TryGetRegistryValue -Key $global:OfficeRegistryPath -Property $searchProperty

    $appsInstalled = [PackageId]::GetNames([PackageId])
    $excludedAppsArray = @()
    if ($null -ne $excludedApps) {
        $textInfo = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo
        $excludedAppsArray = ($excludedApps.Split(',') | ForEach-Object { $textInfo.ToTitleCase($_.Trim()) })
        $appsInstalled = $appsInstalled | Where-Object { $_ -notin $excludedAppsArray }
    }

    return @{
        Installed    = $installed
        Apps         = $appsInstalled
        ExcludedApps = ($null -ne $excludedAppsArray) ? $excludedAppsArray : @()
        ProductId    = $ProductId
    }
}

function Get-OfficeDeploymentToolDownloadUrl {
    try {
        $url = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
        
        Write-Verbose "Making request to: $url"
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        
        $pattern = '"url":"(https://download\.microsoft\.com/download/[^"]+)"'
        
        if ($response -match $pattern) {
            $downloadUrl = $matches[1]
            Write-Verbose "Found download URL: $downloadUrl"
            return $downloadUrl
        } else {
            $altPattern = 'https://download\.microsoft\.com/download/[a-zA-Z0-9\-/]+\.exe'
            
            if ($response -match $altPattern) {
                $downloadUrl = $matches[0]
                Write-Verbose "Found download URL (alternative method): $downloadUrl"
                return $downloadUrl
            } else {
                throw 'Could not find download URL in the page content'
            }
        }
    } catch {
        Write-Error "Failed to retrieve download URL: $($_.Exception.Message)"
        return $null
    }
}

function Test-OfficeInstallation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ProductId]$ProductId
    )
    
    try {
        # Check for Office Click-to-Run installation
        $officeRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
        
        if (Test-Path $officeRegistryPath) {
            $officeConfig = Get-ItemProperty -Path $officeRegistryPath -ErrorAction SilentlyContinue
            
            if ($officeConfig -and $officeConfig.ProductReleaseIds) {
                $installedProducts = $officeConfig.ProductReleaseIds -split ','
                return $installedProducts -contains $ProductId.ToString()
            }
        }
        
        return $false
    } catch {
        Write-Verbose "Error checking Office installation: $($_.Exception.Message)"
        return $false
    }
}

function Test-OfficeDeploymentToolSetup ($Path) {
    try {
        if (-not (Test-Path $Path -ErrorAction Ignore) -and [System.IO.Path]::GetExtension($Path) -ne '.exe') {
            return $false
        }
    
        $helpArgs = @('/?')
        $output = Start-Process -FilePath $Path -ArgumentList $helpArgs -Wait -NoNewWindow -RedirectStandardOutput ([System.IO.Path]::GetTempFileName())

        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        if ($output -notlike '*Office Deployment Tool*') {
            return $false
        }
    } catch {
        Write-Verbose -Message "Error testing Office Deployment Tool setup: $($_.Exception.Message)"
        return $false
    }

    return $true
}

function ThrowTerminating {
    param (
        [Parameter(Mandatory)]
        [System.Exception]
        $Exception,

        [Parameter(Mandatory)]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorCategory]
        $Category,

        [Parameter(Mandatory)]
        [object]
        $TargetObject
    )

    $errorRecord = New-Object System.Management.Automation.ErrorRecord `
    ($Exception, $ErrorId, $Category, $TargetObject)
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

function New-OfficeConfigurationXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.String]
        $ProductId,

        [Parameter()]
        [System.String[]]
        $ExcludeApps = @(),

        [System.Management.Automation.SwitchParameter]
        $Remove
    )
    $languageId = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    $bitness = [Environment]::Is64BitOperatingSystem ? '64' : '32'
    $xml = New-Object System.Xml.XmlDocument

    $config = $xml.CreateElement('Configuration')
    $xml.AppendChild($config) | Out-Null

    $parentNodeName = $Remove ? 'Remove' : 'Add'
    $parentNode = $xml.CreateElement($parentNodeName)
    $parentNode.SetAttribute('OfficeClientEdition', $bitness)
    $config.AppendChild($parentNode) | Out-Null

    $product = $xml.CreateElement('Product')
    $product.SetAttribute('ID', $ProductId)
    $parentNode.AppendChild($product) | Out-Null

    $lang = $xml.CreateElement('Language')
    $lang.SetAttribute('ID', $languageId)
    $product.AppendChild($lang) | Out-Null

    foreach ($app in $ExcludeApps) {
        $exclude = $xml.CreateElement('ExcludeApp')
        $exclude.SetAttribute('ID', $app)
        $product.AppendChild($exclude) | Out-Null
    }

    $display = $xml.CreateElement('Display')
    $display.SetAttribute('Level', 'None')
    $display.SetAttribute('AcceptEULA', 'TRUE')
    $config.AppendChild($display) | Out-Null

    $stringWriter = New-Object System.IO.StringWriter
    $xmlWriter = New-Object System.Xml.XmlTextWriter($stringWriter)
    $xmlWriter.Formatting = 'Indented'
    $xml.WriteTo($xmlWriter)
    $xmlWriter.Flush()
    $stringWriter.ToString()
    
}



function Install-Office365 ($Path, $ProductId, $ExcludeApps) {
    if (-not (Test-OfficeDeploymentToolSetup -Path $Path)) {
        ThrowTerminating -Exception (New-Object System.Exception("The specified executable is not a valid Office Deployment Tool setup.exe: '$Path'")) `
            -ErrorId 'InvalidODTSetup' -Category 'InvalidOperation' -TargetObject $Path
    }

    $configFileContent = New-OfficeConfigurationXml -ProductId $ProductId -ExcludeApps $ExcludeApps

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ODT_Install_$(Get-Random).xml"

    # write the config file to a temp location
    try {
        Set-Content -Path $tempDir -Value $configFileContent -Encoding UTF8 -Force
    } catch {
        ThrowTerminating -Exception (New-Object System.Exception("Failed to create temporary configuration file: '$tempDir'")) `
            -ErrorId 'TempFileCreationFailed' -Category 'InvalidOperation' -TargetObject $tempDir
    }
    
    $arguments = "/configure $tempDir"

    Write-Verbose -Message "Starting Office installation at path '$Path' with arguments: '$arguments'"
    Start-Process -FilePath $Path -ArgumentList $arguments -Wait -NoNewWindow
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

function Compare-ExcludedApps ($CurrentExcludedApps, $DesiredExcludedApps) {
    $diff = Compare-Object -ReferenceObject $CurrentExcludedApps -DifferenceObject $DesiredExcludedApps -SyncWindow 0

    if ($diff) {
        return ($diff.Count -eq 0)
    }
    
    return $true
}

function Test-Administrator {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}
#endregion Functions

#region Classes
[DSCResource()]
class Office365Installer {
    [DscProperty(Key, Mandatory = $true)]
    [System.String] 
    $Path

    [DscProperty()]
    [ProductId] 
    $ProductId = 'O365ProPlusRetail'

    [DscProperty()]
    [PackageId[]]
    $ExcludeApps = @()

    [DscProperty()]
    [System.Boolean]
    $Exist = $true


    Office365Installer() {
    }

    [Office365Installer] Get() {
        $currentState = [Office365Installer]::new()
        
        $officeInstalled = Get-OfficeInstallation -ProductId $this.ProductId
        if ($currentState.Exist) {
            if ($officeInstalled.ExcludedApps -or $this.ExcludeApps) {
                $compareParams = @{
                    CurrentExcludedApps = $officeInstalled.ExcludedApps
                    DesiredExcludedApps = $this.ExcludeApps
                }
                $currentState.Exist = Compare-ExcludedApps @compareParams  
            }
        }

        $currentState.ExcludeApps = $this.ExcludeApps
        $currentState.Path = $this.Path
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        if ($currentState.Exist -ne $this.Exist) {
            return $false
        }

        return $true
    }

    [void] Set() {
        if ($this.Test()) {
            return
        }

        # before installing, ensure we have admin rights
        if (-not (Test-Administrator)) {
            ThrowTerminating -Exception (New-Object System.Exception('Administrator privileges are required to run this script.')) `
                -ErrorId 'InsufficientPrivileges' -Category 'SecurityError' -TargetObject 'Setup'
        }

        if ($this.Exist) {
            $this.Install($false)
        } else {
            $this.Uninstall($false)
        }
    }

    [void] Install([bool] $preTest) {
        if ($preTest -and $this.Test()) {
            return
        }

        Install-Office365 -Path $this.Path -ProductId $this.ProductId -ExcludeApps $this.ExcludeApps
    }

    [void] Install() {
        $this.Install($true)
    }

    [void] Uninstall([bool] $preTest) {
        # TODO: Implement uninstall logic
    }

    [void] Uninstall() {
        $this.Uninstall($true)
    }
    #endregion Classes
}