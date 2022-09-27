function Start-WinDSC {
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $inputFile
    )

    # This is a hack
    $parent = (Get-Item $PSScriptRoot).parent
    Write-Host $parent
    if ($env:PSModulePath -notlike $parent) {
        $env:PSModulePath += ";$parent"
    }

    $obj = Get-Content $inputFile | ConvertFrom-Json

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
}
