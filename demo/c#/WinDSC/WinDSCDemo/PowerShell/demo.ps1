& $PSScriptRoot\addToModulePath.ps1
Import-Module $PSScriptRoot\DscResourceInfo.psm1

$obj = Get-Content Powershell\input.json | ConvertFrom-Json

foreach ($package in $obj.packages)
{
    Write-Host $package.packageIdentifier $package.version
    $resource = @{
        Name = 'WinDSCResourceDemo'
        ModuleName = 'WinDSCResourceDemo'
        Property = @{
          PackageId = $package.packageIdentifier;
          Version = $package.version;
        }
    }
    
    Write-Verbose -Verbose 'Set'
    Invoke-DscResource @resource -Method Set

    Write-Verbose -Verbose 'Test'
    # Force is needed with Format-Table to show the result as PS tries to be too smart and sees a different type
    # of object coming to the pipeline (after the set above) and thus doesn't render it
    Invoke-DscResource @resource -Method Test | Format-Table -Force

    Write-Verbose -Verbose 'Get'
    Invoke-DscResource @resource -Method Get | Format-Table -Force
}
