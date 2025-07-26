using module RustDsc

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the RustDsc PowerShell module.
#>

BeforeAll {
    ## Test if Rust is installed
    $fileHash = '365D072AC4EF47F8774F4D2094108035E2291A0073702DB25FA7797A30861FC9'
    $channel = 'stable'
    if ($null -ne (Get-Command msrustup -CommandType Application -ErrorAction Ignore)) {
        $rustup = 'msrustup'
        $channel = 'ms-stable'
        if ($architecture -eq 'current') {
            $env:MSRUSTUP_TOOLCHAIN = "$architecture"
        }
    } elseif ($null -ne (Get-Command rustup -CommandType Application -ErrorAction Ignore)) {
        $rustup = 'rustup'
    } else {
        $rustup = 'echo'
    }

    if (!(Get-Command 'cargo' -CommandType Application -ErrorAction Ignore)) {
        Write-Verbose -Verbose 'Rust not found, installing...'
        if (!$IsWindows) {
            curl https://sh.rustup.rs -sSf | sh -s -- -y
            $env:PATH += ":$env:HOME/.cargo/bin"
        } else {
            Invoke-WebRequest 'https://static.rust-lang.org/rustup/archive/1.26.0/x86_64-pc-windows-msvc/rustup-init.exe' -OutFile 'temp:/rustup-init.exe'
            $currentHash = (Get-FileHash 'temp:/rustup-init.exe' -Algorithm SHA256).Hash.ToUpperInvariant()
            if ($currentHash -ne $fileHash) {
                throw "Hash mismatch for rustup-init.exe. Expected: $fileHash, Found: $currentHash"
            }

            Write-Verbose -Verbose 'Use the default settings to ensure build works'
            & 'temp:/rustup-init.exe' -y
            $env:PATH += ";$env:USERPROFILE\.cargo\bin"
            Remove-Item temp:/rustup-init.exe -ErrorAction Ignore
        }
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

    It 'Downgrades a tool by specifying an older version' -Skip:(!$IsWindows) {
        $desiredState = @{
            CrateName = 'bat'
            Version   = '0.24.0'
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
            Features  = @('minimal-application')
        }

        Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Set -Property $desiredState

        $finalState = Invoke-DscResource -Name CargoToolInstall -ModuleName RustDsc -Method Get -Property $desiredState
        $finalState.CrateName | Should -Be $desiredState.CrateName
        $finalState.Features | Should -Be $desiredState.Features
        $finalState.Exist | Should -Be $true
    }
}
