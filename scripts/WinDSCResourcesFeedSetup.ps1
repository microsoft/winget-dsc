Param (
   [Parameter(Mandatory)]
   [string] $Token,

   [Parameter(Mandatory)]
   [string] $Alias
)

$winDSCResources = "WinDSCResources"

Invoke-Expression "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) } -AddNetfx"

[System.Environment]::SetEnvironmentVariable('NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED','true')

Write-Output "NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED: $env:NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED"

$Token = $Token.Trim()
$Alias = $Alias.Trim()

if (-not $Alias.Contains('@microsoft.com'))
{
    $Alias = $Alias + '@microsoft.com'
}

$patToken = $Token | ConvertTo-SecureString -AsPlainText -Force
$credsAzureDevopsServices = New-Object System.Management.Automation.PSCredential($Alias, $patToken)

# Reset existing connection to private PowerShell feed.
Write-Output "Connecting to WinDSCResources..."

# Register private feed.
$PSRepositories = Get-PSRepository
if ($PSRepositories.Name -contains $winDSCResources)
{
    Write-Output "Unregistering $winDSCResources PSRepository..."
    Unregister-PSRepository -Name $winDSCResources
}

$packageSources = Get-PackageSource
if ($packageSources.Name -contains $winDSCResources)
{
    Write-Output "Unregistering $winDSCResources package source..."
    Unregister-PackageSource -Name $winDSCResources -ProviderName NuGet
}

Write-Output "Registering WinDSCResources PSRepository..."
Register-PSRepository -Name "WinDSCResources" -SourceLocation "https://pkgs.dev.azure.com/microsoft/WinGetDevOps/_packaging/WinDSCResources_Feed/nuget/v2" -PublishLocation "https://pkgs.dev.azure.com/microsoft/WinGetDevOps/_packaging/WinDSCResources_Feed/nuget/v2" -InstallationPolicy Trusted -Credential $credsAzureDevopsServices

Write-Output "Registering WinDSCResources NuGet PackageSource..."
Register-PackageSource -Name "WinDSCResources" -Location "https://pkgs.dev.azure.com/microsoft/WinGetDevOps/_packaging/WinDSCResources_Feed/nuget/v2" -ProviderName NuGet -Trusted -SkipValidate -Credential $credsAzureDevopsServices

Get-PSRepository
Get-PackageSource