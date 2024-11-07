<#
.SYNOPSIS
    Creates a new DSC (Desired State Configuration) resource module structure.

.DESCRIPTION
    The function New-DscResourceModule function creates a new DSC resource module structure with the specified name and description.
    It sets up the necessary directory structure for resources and tests within the given base path.

.PARAMETER DscResourceModule
    The name of the DSC resource module to create.

.PARAMETER Description
    A description of the DSC resource module.

.PARAMETER BasePath
    The base path where the DSC resource module structure will be created. The default value is the parent directory of the script.

.EXAMPLE
    PS C:\> New-DscResourceModule -DscResourceModule 'Microsoft.Windows.Language' -Description 'DSC Resource for Windows Language'

    This command creates a new DSC resource module named 'Microsoft.Windows.Language' with the specified description in the default base path.
#>
#Requires -Version 7
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '', Justification = 'Positional parameters are used for simplicity. Targeting PS 7+')]
param (
    [Parameter(Mandatory)]
    [string]$DscResourceModule,

    [Parameter(Mandatory)]
    [string]$Description,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]] $DscResourceToExport
)

$basePath = "$PSScriptRoot\..\.."

if (Test-Path $basePath) {
    $resourcePath = Join-Path $basePath 'resources' $DscResourceModule
    $testsPath = Join-Path $basePath 'tests' $DscResourceModule
} else {
    $basePath = $resourcePath = $testsPath = (Resolve-Path '.\').Path
}

# Create directories if they do not exist
if (-not (Test-Path -Path $resourcePath)) {
    Write-Verbose -Message "Creating directory: $resourcePath"
    New-Item -ItemType Directory -Path $resourcePath -Force | Out-Null
}

if (-not (Test-Path -Path $testsPath)) {
    Write-Verbose -Message "Creating test directory: $testsPath"
    New-Item -ItemType Directory -Path $testsPath -Force | Out-Null
}

$moduleManifestPath = (Join-Path $basePath 'resources' $DscResourceModule "$DscResourceModule.psd1")

$moduleManifestParams = @{
    Path              = $moduleManifestPath
    RootModule        = "$DscResourceModule.psm1"
    ModuleVersion     = '0.1.0'
    Author            = 'Microsoft Corporation'
    CompanyName       = 'Microsoft Corporation'
    Copyright         = '(c) Microsoft Corporation. All rights reserved.'
    Description       = $Description
    PowerShellVersion = '7.2'
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    LicenseUri        = 'https://github.com/microsoft/winget-dsc/blob/main/LICENSE'
    ProjectUri        = 'https://github.com/microsoft/winget-dsc'
    Prerelease        = 'alpha'
}

if ($DscResourceToExport) {
    # New module manifest does not properly handle arrays of strings :(
    $moduleManifestParams.Add('DscResourcesToExport', @($DscResourceToExport))
}

if (-not (Test-Path $moduleManifestPath)) {
    if ($PSCmdlet.ShouldProcess($moduleManifestPath, 'Create module manifest')) {
        Write-Verbose -Message ($moduleManifestParams | ConvertTo-Json -Depth 10 | Out-String)
        New-ModuleManifest @moduleManifestParams
    }
}

$psm1Path = Join-Path -Path $resourcePath -ChildPath "$DscResourceModule.psm1"
if (-not (Test-Path $psm1Path)) {
    New-Item -ItemType File -Path $psm1Path -Force | Out-Null
}

$testsFilePath = Join-Path -Path $testsPath -ChildPath "$DscResourceModule.Tests.ps1"
if (-not (Test-Path $testsFilePath)) {
    New-Item -ItemType File -Path $testsFilePath -Force | Out-Null
}

