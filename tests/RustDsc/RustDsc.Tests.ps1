using module RustDsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the RustDsc PowerShell module.
#>

BeforeAll {
    ## Test if Rust is installed
    if (!(Get-Command 'cargo' -CommandType Application -ErrorAction Ignore)) {
        Write-Verbose -Verbose 'Rust not found, installing...'
        if (!$IsWindows) {
            curl https://sh.rustup.rs -sSf | sh -s -- -y
            $env:PATH += ":$env:HOME/.cargo/bin"
        } else {
            Invoke-WebRequest 'https://static.rust-lang.org/rustup/dist/i686-pc-windows-gnu/rustup-init.exe' -OutFile 'temp:/rustup-init.exe'
            Write-Verbose -Verbose 'Use the default settings to ensure build works'
            & 'temp:/rustup-init.exe' -y
            $env:PATH += ";$env:USERPROFILE\.cargo\bin"
            Remove-Item temp:/rustup-init.exe -ErrorAction Ignore
        }
    } else {
        Write-Verbose -Verbose 'Rust found, updating...'
        & $rustup update
    }
    
    Import-Module RustDsc -Force -ErrorAction SilentlyContinue
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'CargoToolInstall'
        $availableDSCResources = (Get-DscResource -Module RustDsc).Name
        $availableDSCResources.count | Should -Be 1
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'CargoToolInstall' {
    It 'Install bat tool globally' -Skip:(!$IsWindows) {
        $desiredState = @{
            CrateName = 'bat'
        }

        Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Get -Property $desiredState
        $finalState.CrateName | Should -Be $desiredState.CrateName
        $finalState.Exist | Should -Be $true
    }

    It 'Install specific version of ripgrep tool globally' -Skip:(!$IsWindows) {
        $desiredState = @{
            CrateName = 'ripgrep'
            Version   = '13.0.0'
        }

        Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Get -Property $desiredState
        $finalState.CrateName | Should -Be $desiredState.CrateName
        $finalState.Version | Should -Be $desiredState.Version
        $finalState.Exist | Should -Be $true
    }

    It 'Uninstall a tool' -Skip:(!$IsWindows) {
        $desiredState = @{
            CrateName = 'bat'
            Exist     = $false
        }

        Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Get -Property $desiredState
        $finalState.CrateName | Should -Be $desiredState.CrateName
        $finalState.Exist | Should -Be $false
    }

    It 'Export installed tools' -Skip:(!$IsWindows) {
        $exportedCrates = [CargoToolInstall]::Export()
        $exportedCrates | Should -Not -BeNullOrEmpty
        $exportedCrates[0].CrateName | Should -Not -BeNullOrEmpty
    }

    It 'Install tool with specific features' -Skip:(!$IsWindows) {
        $desiredState = @{
            CrateName = 'bat'
            Features  = @('minimal_application')
        }

        Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Get -Property $desiredState
        $finalState.CrateName | Should -Be $desiredState.CrateName
        $finalState.Features | Should -Be $desiredState.Features
        $finalState.Exist | Should -Be $true
    }
}
