enum PackageState
{
    NotPresent
    Installed
}

[DSCResource()]
class WinDSCResourceDemo
{
    [DscProperty(Key)]
    [string]$PackageIdentifier

    [DscProperty(Key)]
    [string]$Version

    [string]$Registry

    [DscProperty()]
    [PackageState]$PackageState

    [WinDSCResourceDemo] Get()
    {
        Write-Verbose "Getting current state of $($this.PackageIdentifier) $($this.Version)"
        $result = WinDSCResourceGetHelper -PackageIdentifier $this.PackageIdentifier -version $this.Version
        return $result
    }

    [bool] Test()
    {
        Write-Verbose "Testing $($this.PackageIdentifier) $($this.Version)"
        $test = WinDSCResourceTestHelper -PackageIdentifier $this.PackageIdentifier -version $this.Version
        return $test

    }

    [void] Set() {
        Write-Verbose "Setting $($this.PackageIdentifier) $($this.Version)"
        WinDSCResourceSetHelper -PackageIdentifier $this.PackageIdentifier -version $this.Version
    }

}

function WinDSCResourceGetHelper
{
    [CmdletBinding()]
    param([string]$packageIdentifier, [string]$version)

    try
    {
        $state = IsRegistryKeyPresent -PackageIdentifier $packageIdentifier -version $version
        $registry = GetRegistryKey -PackageIdentifier $packageIdentifier -version $version
        $result = @{
            PackageIdentifier = $PackageIdentifier
            Version = $version
            PackageState = $state
            Registry = $registry
        }
    }
    catch
    {
        throw $_
    }

    return $result
}

function WinDSCResourceTestHelper
{
    [CmdletBinding()]
    param([string]$packageIdentifier, [string]$version)

    try
    {
        $state = IsRegistryKeyPresent -PackageIdentifier $packageIdentifier -version $version
        return $state -eq [PackageState]::Installed
    }
    catch
    {
        throw $_
    }
}

function WinDSCResourceSetHelper
{
    [CmdletBinding()]
    param([string]$packageIdentifier, [string]$version)

    try
    {
        # We write to "HKLM:\SOFTWARE\SOFTWARE\WinDSCDemo\publisher\package\version for proff of concept.
        $registryKey = "HKCU:\SOFTWARE\WinDSCDemo";

        if (-Not (Test-Path $registryKey))
        {
            New-Item -Path "HKCU:\SOFTWARE" -Name "WinDSCDemo" -Force
        }

        $parts = $PackageIdentifier.Split('.');
        foreach ($part in $parts)
        {
            $tmpRegistryKey = $registryKey + '\' + $part;
            if (-Not (Test-Path $tmpRegistryKey))
            {
                New-Item -Path $registryKey -Name $part
            }
            $registryKey = $tmpRegistryKey;
        }

        New-Item -Path $registryKey -Name $version -Force
    }
    catch
    {
        throw $_
    }
}

function GetRegistryKey
{
    [CmdletBinding()]
    param([string]$packageIdentifier, [string]$version)

    $registryKey = "HKCU:\SOFTWARE\WinDSCDemo";

    $parts = $packageIdentifier.Split('.');
    foreach ($part in $parts)
    {
        $registryKey += '\' + $part;
    }

    $registryKey += '\' + $version;
    return $registryKey;
}

function IsRegistryKeyPresent
{
    [CmdletBinding()]
    param([string]$packageIdentifier, [string]$version)

    try
    {
        $registryKey = GetRegistryKey -PackageIdentifier $packageIdentifier -version $version

        if (Test-Path $registryKey)
        {
            return [PackageState]::Installed
        }

        return [PackageState]::NotPresent
    }
    catch
    {
        throw $_
    }
}
