function New-DscResourceModule
{
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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DscResourceModule,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter()]
        [string]$BasePath = (Join-Path $PSScriptRoot '..' '..')

    )

    $resourcePath = Join-Path $BasePath 'resources' $DscResourceModule
    $testsPath = Join-Path $BasePath 'tests' $DscResourceModule

    # Create directories if they do not exist
    if (-not (Test-Path -Path $resourcePath))
    {
        Write-Verbose -Message "Creating directory: $resourcePath"
        $null = New-Item -ItemType Directory -Path $resourcePath -Force
    }

    if (-not (Test-Path -Path $testsPath))
    {
        Write-Verbose -Message "Creating test directory: $testsPath"
        $null = New-Item -ItemType Directory -Path $testsPath -Force
    }

    $moduleManifestPath = (Join-Path $BasePath 'resources' $DscResourceModule "$DscResourceModule.psd1")

    $moduleManifestParams = @{
        Path                 = $moduleManifestPath
        RootModule           = "$DscResourceModule.psm1"
        ModuleVersion        = '0.1.0'
        Author               = 'Microsoft Corporation'
        CompanyName          = 'Microsoft Corporation'
        Copyright            = '(c) Microsoft Corporation. All rights reserved.'
        Description          = $Description
        PowerShellVersion    = '7.2'
        DscResourcesToExport = @()
    }

    if (-not (Test-Path $moduleManifestPath))
    {
        Write-Verbose -Message ("Creating module manifest in: $moduleManifestPath with")
        Write-Verbose -Message ($moduleManifestParams | ConvertTo-Json -Depth 10 | Out-String)
        New-ModuleManifest @moduleManifestParams

        # Workaround for issue: https://github.com/PowerShell/PowerShell/issues/5922
        $fileContent = Get-Content $moduleManifestPath
        $newLicenseUri = "LicenseUri = 'https://github.com/microsoft/winget-dsc/blob/main/LICENSE'"
        $fileContent = $fileContent -replace '# LicenseUri = ''''', $newLicenseUri
        $newProjectUri = "ProjectUri = 'https://github.com/microsoft/winget-dsc'"
        $fileContent = $fileContent -replace '# ProjectUri = ''''', $newProjectUri
        $newPrerelease = "Prerelease = 'alpha'"
        $fileContent = $fileContent -replace '# Prerelease = ''''', $newPrerelease
        # TODO: Add tags
        
        Set-Content -Path $moduleManifestPath -Value $fileContent
    }

    $psm1Path = Join-Path -Path $resourcePath -ChildPath "$DscResourceModule.psm1"
    if (-not (Test-Path $psm1Path))
    {
        $null = New-Item -ItemType File -Path $psm1Path -Force    
    }

    $testsFilePath = Join-Path -Path $testsPath -ChildPath "$DscResourceModule.Tests.ps1"
    if (-not (Test-Path $testsFilePath))
    {
        $null = New-Item -ItemType File -Path $testsFilePath -Force
    }
}