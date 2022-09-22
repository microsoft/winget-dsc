
$obj = Get-Content ..\input2.json | ConvertFrom-Json

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
    
    Invoke-DscResource @resource -Method Set
}
