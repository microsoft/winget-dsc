#Requires -Version 7

param (
    [Parameter()]
    [string] $repoRootPath = (Get-Item $PSScriptRoot).Parent.Parent.FullName,

    [Parameter()]
    [array] $modules = (Get-ChildItem -Path (Join-Path $repoRootPath -ChildPath 'resources') -File -Recurse -Filter '*.psm1')
)

Write-Verbose ("repoRootPath: $repoRootPath") -Verbose
Write-Verbose ("modules: $($modules.Count)") -Verbose

BeforeDiscovery {
    $moduleResources = [System.Collections.ArrayList]@()

    foreach ($module in $modules) {
        $moduleResources += @{
            moduleName = $module.BaseName
            modulePath = $module.FullName
        }
    }
}

Describe 'Module tests' {
    Context 'General resource folder test' -Tags 'FunctionalQuality' {
        It '[<moduleName>]' -TestCases $testCases -Skip:(-not $scriptAnalyzerRules) {
            $functionFile = Get-ChildItem -Path $sourcePath -Recurse -Include "$Name.ps1"

            $pssaResult = (Invoke-ScriptAnalyzer -Path $functionFile.FullName)
            $report = $pssaResult | Format-Table -AutoSize | Out-String -Width 110
            $pssaResult | Should -BeNullOrEmpty -Because `
                "some rule triggered.`r`n`r`n $report"
        }

        It '[<moduleName>] Should import without error' -TestCases $moduleResources {

            param (
                [string] $modulePath,
                [string] $moduleName
            )

            { Import-Module -Name $modulePath -Force -ErrorAction Stop } | Should -Not -Throw

            Get-Module -Name $moduleName | Should -Not -BeNullOrEmpty
        }

        It '[<moduleName>] Should remove without error' -TestCases $moduleResources {
            { Remove-Module -Name $moduleName -Force -ErrorAction Stop } | Should -Not -Throw

            Get-Module $moduleName | Should -BeNullOrEmpty
        }

        It '[<moduleName>] Should have unit test' -TestCases $moduleResources {
            Get-ChildItem -Path 'tests\' -Recurse -Include "$ModuleName.Tests.ps1" | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Quality checks' -Tags 'TestQuality' {
        BeforeDiscovery {
            if (Get-Command -Name Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
                $scriptAnalyzerRules = Get-ScriptAnalyzerRule
            } else {
                if ($ErrorActionPreference -ne 'Stop') {
                    Write-Warning -Message 'ScriptAnalyzer not found!'
                } else {
                    throw 'ScriptAnalyzer not found!'
                }
            }
        }

        It '[<moduleName>] Should pass PSScriptAnalyzer' -TestCases $moduleResources -Skip:(-not $scriptAnalyzerRules) {
            param (
                [string] $modulePath,
                [string] $moduleName
            )

            $pssaResult = Invoke-ScriptAnalyzer -Path $modulePath
            $report = $pssaResult | Format-Table -AutoSize | Out-String -Width 110
            $pssaResult | Should -BeNullOrEmpty -Because `
                "some rule triggered.`r`n`r`n $report"
        }
    }

    Context 'Documentation checks' -Tags 'DocQuality' -ForEach $moduleResources {
        $moduleResource = $_
        $moduleImport = Import-PowerShellDataFile -Path $moduleResource.ModulePath.Replace('.psm1', '.psd1')

        $resources = [System.Collections.ArrayList]@()

        foreach ($resource in $moduleImport.DscResourcesToExport) {
            $resources += @{
                moduleName = $moduleResource.ModuleName
                resource   = $resource
                HelpFile   = Join-Path $repoRootPath 'resources' 'Help' $moduleResource.ModuleName "$resource.md"
            }
        }

        It '[<moduleName>] Should have a help file for [<resource>] resource' -TestCases $resources {
            param (
                [string] $moduleName,
                [string] $resource,
                [string] $helpFile
            )

            $expectedFile = Test-Path $helpFile -ErrorAction SilentlyContinue
            $expectedFile | Should -Be $true
        }

        It '[<moduleName>] Should have a help file for [<resource>] resource that is not empty' -TestCases $resources {
            param (
                [string] $moduleName,
                [string] $resource,
                [string] $helpFile
            )

            $file = Get-Item -Path $helpFile -ErrorAction SilentlyContinue
            $file.Length | Should -BeGreaterThan 0
        }
    }
}
