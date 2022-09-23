& $PSScriptRoot\addToModulePath.ps1

$obj = Get-Content ..\input.json | ConvertFrom-Json

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

# Delete key
Write-Verbose -Verbose 'Deleting bad rum'
Remove-Item -Path "HKCU:SOFTWARE\WinDSCDemo\Rum\CaptainMorgan" -Force -Recurse

# Test with one
$morganResource = @{
    Name = 'WinDSCResourceDemo'
    ModuleName = 'WinDSCResourceDemo'
    Property = @{
      PackageId = "Rum.CaptainMorgan";
      Version = "0.1";
    }
}

Write-Verbose -Verbose 'Test Rum.CaptainMorgan 0.1'
Invoke-DscResource @morganResource -Method Test | Format-Table -Force

# Run Invoke-DscResource with set again.
Write-Verbose -Verbose 'Set'
Invoke-DscResource @morganResource -Method Set

Write-Verbose -Verbose 'Test again Rum.CaptainMorgan 0.1'
Invoke-DscResource @morganResource -Method Test | Format-Table -Force
