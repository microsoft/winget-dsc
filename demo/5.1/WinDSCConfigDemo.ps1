Configuration WinDSCConfigDemo
{
    param([string]$inputFile)

    Import-DSCResource -ModuleName "PSDesiredStateConfiguration" -ModuleVersion "1.1"
    Import-DSCResource -ModuleName "WinDSCResourceDemo" -ModuleVersion "0.0.1"

    $obj = Get-Content $inputFile | ConvertFrom-Json

    Node localhost
    {
        foreach ($package in $obj.packages)
        {
            $uniqueId = [guid]::NewGuid()
            WinDSCResourceDemo $uniqueId.Guid.Replace("-","")
            {
                PackageId = $package.packageIdentifier
                Version = $package.version
            }
        }
    }
}

WinDSCConfigDemo -inputFile ..\input.json -OutputPath .\OutDemo
