#Requires -Version 7

param (
    [Parameter()]
    [string] $repoRootPath = (Get-Item $PSScriptRoot).Parent.Parent.FullName,

    [Parameter()]
    [array] $modules = (Get-ChildItem -Path (Join-Path $repoRootPath -ChildPath 'resources') -File -Recurse -Filter '*.psm1')
)

Write-Verbose ("repoRootPath: $repoRootPath") -Verbose
Write-Verbose ("modules: $($modules.Count)") -Verbose

Describe 'Module tests' -Tags 'FunctionalQuality' {
    Context 'General resource folder test' {
        $moduleResources = [System.Collections.ArrayList]@()

        foreach ($module in $modules) {
            $moduleResources += @{
                moduleName = $module.BaseName
                modulePath = $module.FullName
            }
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
    }
}
