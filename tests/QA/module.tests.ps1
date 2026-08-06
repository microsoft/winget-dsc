#Requires -Version 7

param (
    [Parameter()]
    [string] $repoRootPath = (Get-Item $PSScriptRoot).Parent.Parent.FullName,

    [Parameter()]
    [array] $modules = (Get-ChildItem -Path (Join-Path $repoRootPath -ChildPath 'resources') -File -Recurse -Filter '*.psm1')
)

Write-Verbose ("repoRootPath: $repoRootPath") -Verbose
Write-Verbose ("modules: $($modules.Count)") -Verbose

#region Functions
function Get-MarkdownHeadings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $fileContent = Get-Content -Path $FilePath

    $headings = @()

    # Use pattern to capture all headings
    $headingPattern = '^(#+)\s+(.*)'

    foreach ($line in $fileContent) {
        if ($line -match $headingPattern) {
            $level = $matches[1].Length
            $text = $matches[2]

            $heading = [PSCustomObject]@{
                Level = $level
                Text  = $text
            }

            $headings += $heading
        }
    }

    return $headings
}

function Get-MdCodeBlock {
    [CmdletBinding()]
    [OutputType([CodeBlock])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string[]]
        [SupportsWildcards()]
        $Path,

        [Parameter()]
        [string]
        $BasePath = '.',

        [Parameter()]
        [string]
        $Language
    )

    process {
        foreach ($unresolved in $Path) {
            foreach ($file in (Resolve-Path -Path $unresolved).Path) {
                $file = (Resolve-Path -Path $file).Path
                $BasePath = (Resolve-Path -Path $BasePath).Path
                $escapedRoot = [regex]::Escape($BasePath)
                $relativePath = $file -replace "$escapedRoot\\", ''


                # This section imports files referenced by PyMdown snippet syntax
                # Example: --8<-- "abbreviations.md"
                # Note: This function only supports very basic snippet syntax.
                # See https://facelessuser.github.io/pymdown-extensions/extensions/snippets/ for documentation on the Snippets PyMdown extension
                $lines = [System.IO.File]::ReadAllLines($file, [System.Text.Encoding]::UTF8) | ForEach-Object {
                    if ($_ -match '--8<-- "(?<file>[^"]+)"') {
                        $snippetPath = Join-Path -Path $BasePath -ChildPath $Matches.file
                        if (Test-Path -Path $snippetPath) {
                            Get-Content -Path $snippetPath
                        } else {
                            Write-Warning "Snippet not found: $snippetPath"
                        }
                    } else {
                        $_
                    }
                }


                $lineNumber = 0
                $code = $null
                $state = [MdState]::Undefined
                $content = [System.Text.StringBuilder]::new()

                foreach ($line in $lines) {
                    $lineNumber++
                    switch ($state) {
                        'Undefined' {
                            if ($line -match '^\s*```(?<lang>\w+)?' -and ([string]::IsNullOrWhiteSpace($Language) -or $Matches.lang -eq $Language)) {
                                $state = [MdState]::InCodeBlock
                                $code = [CodeBlock]@{
                                    Source     = $relativePath
                                    Language   = $Matches.lang
                                    LineNumber = $lineNumber
                                }
                            } elseif (($inlineMatches = [regex]::Matches($line, '(?<!`)`(#!(?<lang>\w+) )?(?<code>[^`]+)`(?!`)'))) {
                                if (-not [string]::IsNullOrWhiteSpace($Language) -and $inlineMatch.Groups.lang -ne $Language) {
                                    continue
                                }
                                foreach ($inlineMatch in $inlineMatches) {
                                    [CodeBlock]@{
                                        Source     = $relativePath
                                        Language   = $inlineMatch.Groups.lang
                                        Content    = $inlineMatch.Groups.code
                                        LineNumber = $lineNumber
                                        Position   = $inlineMatch.Index
                                        Inline     = $true
                                    }
                                }
                            }
                        }

                        'InCodeBlock' {
                            if ($line -match '^\s*```') {
                                $state = [MdState]::Undefined
                                $code.Content = $content.ToString()
                                $code
                                $code = $null
                                $null = $content.Clear()
                            } else {
                                $null = $content.AppendLine($line)
                            }
                        }
                    }
                }
            }
        }
    }
}
#endRegion Functions

#region Enum
enum MdState {
    Undefined
    InCodeBlock
}
#endRegion Enum
class CodeBlock {
    [string] $Source
    [string] $Language
    [string] $Content
    [int]    $LineNumber
    [int]    $Position
    [bool]   $Inline

    [string] ToString() {
        return '{0}:{1}:{2}' -f $this.Source, $this.LineNumber, $this.Language
    }
}
#region Classes

#endRegion Classes

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

        # For the resources
        $resources = [System.Collections.ArrayList]@()

        # For the code blocks to capture in the examples
        $codeBlocks = [System.Collections.ArrayList]@()

        foreach ($resource in $moduleImport.DscResourcesToExport) {
            $helpFile = Join-Path $repoRootPath 'resources' 'Help' $moduleResource.ModuleName "$resource.md"

            $resources += @{
                moduleName = $moduleResource.ModuleName
                resource   = $resource
                helpFile   = $helpFile
                CodeBlock  = Get-MdCodeBlock -Path $helpFile -Language 'powershell' -ErrorAction SilentlyContinue
            }

            $blocks = Get-MdCodeBlock -Path $helpFile -Language 'powershell' -ErrorAction SilentlyContinue
            if (-not $blocks) {
                $codeBlocks += @{
                    moduleName = $moduleResource.ModuleName
                    resource   = $resource
                    content    = 'No code block found'
                    language   = 'powershell'
                }
            }

            foreach ($block in $blocks) {
                $codeBlocks += @{
                    moduleName = $moduleResource.ModuleName
                    resource   = $resource
                    content    = $block.Content
                    language   = $block.Language
                }
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

        It '[<moduleName>] Should have a help file for [<resource>] resource with heading 1' -TestCases $resources {
            param (
                [string] $moduleName,
                [string] $resource,
                [string] $helpFile
            )

            $headings = Get-MarkdownHeadings -FilePath $helpFile -ErrorAction SilentlyContinue

            $h1 = $headings | Where-Object { $_.Level -eq 1 -and $_.Text -eq $moduleName }
            $h1 | Should -Not -BeNullOrEmpty
        }

        It '[<moduleName>] Should have a help file for [<resource>] resource with heading 2 matching SYNOPSIS' -TestCases $resources {
            param (
                [string] $moduleName,
                [string] $resource,
                [string] $helpFile
            )

            $headings = Get-MarkdownHeadings -FilePath $helpFile -ErrorAction SilentlyContinue

            $h2 = $headings | Where-Object { $_.Level -eq 2 -and $_.Text -eq 'SYNOPSIS' }
            $h2 | Should -Not -BeNullOrEmpty
        }

        It '[<moduleName>] Should have a help file for [<resource>] resource with heading 2 matching DESCRIPTION' -TestCases $resources {
            param (
                [string] $moduleName,
                [string] $resource,
                [string] $helpFile
            )

            $headings = Get-MarkdownHeadings -FilePath $helpFile -ErrorAction SilentlyContinue

            $h2 = $headings | Where-Object { $_.Level -eq 2 -and $_.Text -eq 'DESCRIPTION' }
            $h2 | Should -Not -BeNullOrEmpty
        }

        It '[<moduleName>] Should have a help file for [<resource>] resource with heading 2 matching PARAMETERS' -TestCases $resources {
            param (
                [string] $moduleName,
                [string] $resource,
                [string] $helpFile
            )

            $headings = Get-MarkdownHeadings -FilePath $helpFile -ErrorAction SilentlyContinue

            $h2 = $headings | Where-Object { $_.Level -eq 2 -and $_.Text -eq 'PARAMETERS' }
            $h2 | Should -Not -BeNullOrEmpty
        }

        It '[<moduleName>] Should have a help file for [<resource>] resource with heading 2 matching EXAMPLES' -TestCases $resources {
            param (
                [string] $moduleName,
                [string] $resource,
                [string] $helpFile
            )

            $headings = Get-MarkdownHeadings -FilePath $helpFile -ErrorAction SilentlyContinue

            $h2 = $headings | Where-Object { $_.Level -eq 2 -and $_.Text -eq 'EXAMPLES' }
            $h2 | Should -Not -BeNullOrEmpty
        }

        It '[<moduleName>] Should have a help file for [<resource>] with 1 example' -TestCases $resources {
            param (
                [string] $moduleName,
                [string] $resource,
                [string] $helpFile
            )

            $headings = Get-MarkdownHeadings -FilePath $helpFile -ErrorAction SilentlyContinue

            $h3 = $headings | Where-Object { $_.Level -eq 3 -and $_.Text -eq 'EXAMPLE 1' }
            $h3 | Should -Not -BeNullOrEmpty
        }

        It '[<moduleName>] Should have at least a PowerShell coding example with Invoke-DscResource' -TestCases $codeBlocks {
            param (
                [string] $ModuleName,
                [string] $Content,
                [string] $Language
            )

            $Content | Should -Match "Invoke-DscResource -ModuleName $ModuleName -Name $ResourceName"
        }
    }
}

