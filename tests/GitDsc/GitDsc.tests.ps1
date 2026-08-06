using module GitDsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the GitDsc PowerShell module.
#>

BeforeAll {
    if ((Get-Module -Name PSDesiredStateConfiguration -ListAvailable).Version -ne '2.0.7') {
        Write-Verbose -Message 'Installing PSDesiredStateConfiguration module.' -Verbose
        Install-Module -Name PSDesiredStateConfiguration -Force -SkipPublisherCheck -RequiredVersion '2.0.7'
    }

    Import-Module GitDsc
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'GitClone', 'GitRemote', 'GitConfigUserName', 'GitConfigUserEmail', 'GitConfig'
        $availableDSCResources = (Get-DscResource -Module GitDsc).Name
        $availableDSCResources.count | Should -Be 5
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'GitDsc' {
    It 'Clones a repository' {
        $desiredState = @{
            HttpsUrl      = 'https://github.com/microsoft/winget-dsc.git'
            RootDirectory = $env:TEMP
        }

        Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.HttpsUrl | Should -Be $desiredState.HttpsUrl
        $finalState.Ensure | Should -Be 'Present'
        $finalState.RootDirectory | Should -Be $desiredState.RootDirectory
    }

    It 'Clones a repository with a specific folder name' {
        $desiredState = @{
            HttpsUrl      = 'https://github.com/microsoft/winget-dsc.git'
            RootDirectory = $env:TEMP
            FolderName    = 'winget-dsc-clone-test'
        }

        Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.HttpsUrl | Should -Be $desiredState.HttpsUrl
        $finalState.Ensure | Should -Be 'Present'
        $finalState.RootDirectory | Should -Be $desiredState.RootDirectory
        $finalState.FolderName | Should -Be $desiredState.FolderName
    }

    It 'Clones a repository without checkout and file contents' {
        $desiredState = @{
            HttpsUrl      = 'https://github.com/microsoft/winget-dsc.git'
            RootDirectory = $env:TEMP
            ExtraArgs     = @('--filter=blob:none', '--no-checkout')
        }

        Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.HttpsUrl | Should -Be $desiredState.HttpsUrl
        $finalState.Ensure | Should -Be 'Present'
        $finalState.RootDirectory | Should -Be $desiredState.RootDirectory
    }

    It 'Should not clone a repository if an incorrect URL is provided' {
        $desiredState = @{
            HttpsUrl      = 'https://invalid-url.git'
            RootDirectory = $env:TEMP
        }

        { (Invoke-DscResource -Name GitClone -ModuleName GitDsc -Method Get -Property $desiredState -ErrorAction Stop) } | Should -Throw
    }
}

Describe 'GitConfig - global scope' {
    BeforeAll {
        # Capture the original value so we can restore it after the test suite
        $script:originalLongPaths = & git config --global core.longpaths 2>$null
    }

    AfterAll {
        # Restore original state
        if ($null -ne $script:originalLongPaths) {
            & git config --global core.longpaths $script:originalLongPaths
        } else {
            & git config --global --unset core.longpaths 2>$null
        }
    }

    It 'Sets a global git config value' {
        $desiredState = @{
            Name           = 'core.longpaths'
            Value          = 'true'
            ConfigLocation = 'global'
        }

        Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be $desiredState.Name
        $finalState.Value | Should -Be $desiredState.Value
        $finalState.Exist | Should -BeTrue
    }

    It 'Reports InDesiredState when value already matches' {
        $desiredState = @{
            Name           = 'core.longpaths'
            Value          = 'true'
            ConfigLocation = 'global'
        }

        # Ensure the value is set first
        Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Set -Property $desiredState

        $testResult = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Test -Property $desiredState
        $testResult.InDesiredState | Should -BeTrue
    }

    It 'Reports not InDesiredState when value differs' {
        # Set value to 'false'
        & git config --global core.longpaths false

        $desiredState = @{
            Name           = 'core.longpaths'
            Value          = 'true'
            ConfigLocation = 'global'
        }

        $testResult = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Test -Property $desiredState
        $testResult.InDesiredState | Should -BeFalse
    }

    It 'Updates a global git config value' {
        # Set initial value
        & git config --global core.longpaths false

        $desiredState = @{
            Name           = 'core.longpaths'
            Value          = 'true'
            ConfigLocation = 'global'
        }

        Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.Value | Should -Be 'true'
        $finalState.Exist | Should -BeTrue
    }

    It 'Removes a global git config value when Exist is false' {
        # Ensure the value exists first
        & git config --global core.longpaths true

        $desiredState = @{
            Name           = 'core.longpaths'
            ConfigLocation = 'global'
            Exist          = $false
        }

        Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.Exist | Should -BeFalse
    }

    It 'Reports InDesiredState when key is absent and Exist is false' {
        # Ensure the key does not exist
        & git config --global --unset core.longpaths 2>$null

        $desiredState = @{
            Name           = 'core.longpaths'
            ConfigLocation = 'global'
            Exist          = $false
        }

        $testResult = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Test -Property $desiredState
        $testResult.InDesiredState | Should -BeTrue
    }

    It 'Sets init.defaultBranch to main' {
        $desiredState = @{
            Name           = 'init.defaultBranch'
            Value          = 'main'
            ConfigLocation = 'global'
        }

        Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be 'init.defaultBranch'
        $finalState.Value | Should -Be 'main'
        $finalState.Exist | Should -BeTrue
    }
}

Describe 'GitConfig - local scope' {
    BeforeAll {
        # Create a temporary git repository for local-scope tests
        $script:tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) "gitconfig-test-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:tempRepo | Out-Null
        & git -C $script:tempRepo init
    }

    AfterAll {
        # Clean up the temporary repository
        if (Test-Path $script:tempRepo) {
            Remove-Item -Recurse -Force -Path $script:tempRepo
        }
    }

    It 'Sets a local git config value' {
        $desiredState = @{
            Name             = 'core.autocrlf'
            Value            = 'input'
            ConfigLocation   = 'local'
            ProjectDirectory = $script:tempRepo
        }

        Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Get -Property $desiredState
        $finalState.Name | Should -Be 'core.autocrlf'
        $finalState.Value | Should -Be 'input'
        $finalState.Exist | Should -BeTrue
    }

    It 'Reports InDesiredState for a local git config value' {
        $desiredState = @{
            Name             = 'core.autocrlf'
            Value            = 'input'
            ConfigLocation   = 'local'
            ProjectDirectory = $script:tempRepo
        }

        # Ensure the value is set first
        Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Set -Property $desiredState

        $testResult = Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Test -Property $desiredState
        $testResult.InDesiredState | Should -BeTrue
    }

    It 'Throws when ProjectDirectory is missing for local scope' {
        $desiredState = @{
            Name           = 'core.autocrlf'
            Value          = 'input'
            ConfigLocation = 'local'
        }

        { Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Get -Property $desiredState } | Should -Throw
    }

    It 'Throws when ProjectDirectory does not exist' {
        $desiredState = @{
            Name             = 'core.autocrlf'
            Value            = 'input'
            ConfigLocation   = 'local'
            ProjectDirectory = 'C:\this\path\does\not\exist'
        }

        { Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Get -Property $desiredState } | Should -Throw
    }
}

Describe 'GitConfig - Export' {
    BeforeAll {
        # Create a temporary git repository for Export local-scope tests
        $script:exportTempRepo = Join-Path ([System.IO.Path]::GetTempPath()) "gitconfig-export-test-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:exportTempRepo | Out-Null
        & git -C $script:exportTempRepo init
        & git -C $script:exportTempRepo config core.autocrlf input
        & git -C $script:exportTempRepo config core.filemode false

        # Ensure at least one known global setting exists for the export tests
        & git config --global core.longpaths true
    }

    AfterAll {
        & git config --global --unset core.longpaths 2>$null

        if (Test-Path $script:exportTempRepo) {
            Remove-Item -Recurse -Force -Path $script:exportTempRepo
        }
    }

    It 'Exports all global git config entries as GitConfig objects' {
        $instance = [GitConfig]::new()
        $results = $instance.Export([ConfigLocation]::global)

        $results | Should -Not -BeNullOrEmpty
        $results | ForEach-Object {
            $_ | Should -BeOfType ([GitConfig])
            $_.ConfigLocation | Should -Be ([ConfigLocation]::global)
            $_.Exist | Should -BeTrue
            $_.Name | Should -Not -BeNullOrEmpty
        }
    }

    It 'Export includes a known global setting' {
        $instance = [GitConfig]::new()
        $results = $instance.Export([ConfigLocation]::global)

        $match = $results | Where-Object { $_.Name -eq 'core.longpaths' }
        $match | Should -Not -BeNullOrEmpty
        $match.Value | Should -Be 'true'
    }

    It 'Exports local git config entries for a repository' {
        $instance = [GitConfig]::new()
        $results = $instance.Export([ConfigLocation]::local, $script:exportTempRepo)

        $results | Should -Not -BeNullOrEmpty
        $results | ForEach-Object {
            $_ | Should -BeOfType ([GitConfig])
            $_.ConfigLocation | Should -Be ([ConfigLocation]::local)
            $_.ProjectDirectory | Should -Be $script:exportTempRepo
            $_.Exist | Should -BeTrue
        }
    }

    It 'Export includes known local settings' {
        $instance = [GitConfig]::new()
        $results = $instance.Export([ConfigLocation]::local, $script:exportTempRepo)

        $autocrlfEntry = $results | Where-Object { $_.Name -eq 'core.autocrlf' }
        $autocrlfEntry | Should -Not -BeNullOrEmpty
        $autocrlfEntry.Value | Should -Be 'input'

        $filemodeEntry = $results | Where-Object { $_.Name -eq 'core.filemode' }
        $filemodeEntry | Should -Not -BeNullOrEmpty
        $filemodeEntry.Value | Should -Be 'false'
    }

    It 'Single-argument Export overload returns the same results as the two-argument overload for global scope' {
        $instance = [GitConfig]::new()
        $twoArg = $instance.Export([ConfigLocation]::global, '')
        $oneArg = $instance.Export([ConfigLocation]::global)

        $oneArg.Count | Should -Be $twoArg.Count
    }

    It 'Exports all settings when ConfigLocation is none' {
        $instance = [GitConfig]::new()
        $results = $instance.Export([ConfigLocation]::none)

        # none scope lists settings from all scopes - should be non-empty
        $results | Should -Not -BeNullOrEmpty
        $results | ForEach-Object {
            $_ | Should -BeOfType ([GitConfig])
            $_.Exist | Should -BeTrue
        }
    }
}

Describe 'GitConfig - validation' {
    It 'Throws when Value is not specified and Exist is true' {
        $desiredState = @{
            Name           = 'core.longpaths'
            ConfigLocation = 'global'
            Exist          = $true
        }

        { Invoke-DscResource -Name GitConfig -ModuleName GitDsc -Method Set -Property $desiredState } | Should -Throw
    }
}

AfterAll {
    # Clean up init.defaultBranch if we set it during tests
    & git config --global --unset init.defaultBranch 2>$null
}
