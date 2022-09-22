enum PackageState
{
    NotPresent
    Installed
}

[DSCResource()]
class WinDSCResourceDemo
{
    [DscProperty(Key)]
    [string]$PackageId

    [DscProperty(Key)]
    [string]$Version

    [DscProperty()]
    [PackageState]$PackageState

    [WinDSCResourceDemo] Get()
    {
        Write-Verbose "Getting current state of $($this.PackageId) $($this.Version)"
        $result = WinDSCResourceGetHelper -packageId $this.PackageId -version $this.Version
        return $result
    }

    [bool] Test()
    {
        Write-Verbose "Testing $($this.PackageId) $($this.Version)"
        $test = WinDSCResourceTestHelper -packageId $this.PackageId -version $this.Version
        return $test

    }

    [void] Set() {
        Write-Verbose "Setting $($this.PackageId) $($this.Version)"
        WinDSCResourceSetHelper -packageId $this.packageId -version $this.Version
    }

}

function WinDSCResourceGetHelper
{
    [CmdletBinding()]
    param([string]$packageId, [string]$version)

    try
    {
        $state = IsRegistryKeyPresent -packageId $packageId -version $version
        $result = @{
            PackageId = $packageId
            Version = $version
            PackageState = $state
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
    param([string]$packageId, [string]$version)

    try
    {
        $state = IsRegistryKeyPresent -packageId $packageId -version $version
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
    param([string]$packageId, [string]$version)

    try
    {
        # We write to "HKLM:\SOFTWARE\SOFTWARE\WinDSCDemo\publisher\package\version for proff of concept.
        $registryKey = "HKLM:\SOFTWARE\WinDSCDemo";

        if (-Not (Test-Path $registryKey))
        {
            New-Item -Path "HKLM:\SOFTWARE" -Name "WinDSCDemo"
        }

        $parts = $packageId.Split('.');
        foreach ($part in $parts)
        {
            $tmpRegistryKey = $registryKey + '\' + $part;
            if (-Not (Test-Path $tmpRegistryKey))
            {
                New-Item -Path $registryKey -Name $part
            }
            $registryKey = $tmpRegistryKey;
        }

        New-Item -Path $registryKey -Name $version
    }
    catch
    {
        throw $_
    }
}

function GetRegistryKey
{
    [CmdletBinding()]
    param([string]$packageId, [string]$version)

    $registryKey = "HKLM:\SOFTWARE\WinDSCDemo";

    $parts = $packageId.Split('.');
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
    param([string]$packageId, [string]$version)

    try
    {
        $registryKey = GetRegistryKey -packageId $packageId -version $version

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
