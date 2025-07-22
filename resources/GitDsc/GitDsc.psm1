# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

enum Ensure {
    Absent
    Present
}

enum ConfigLocation {
    none
    global
    system
    worktree
    local
}

# Assert once that Git is already installed on the system.
Assert-Git

#region DSCResources
[DSCResource()]
class GitClone {
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$HttpsUrl

    [DscProperty()]
    [string]$RemoteName

    # The root directory where the project will be cloned to. (i.e. the directory where you expect to run `git clone`)
    [DscProperty(Mandatory)]
    [string]$RootDirectory

    # The folder name where the repository will be cloned to. If not specified, it will be derived from the HTTPS URL.
    [DscProperty()]
    [string]$FolderName

    [GitClone] Get() {
        $currentState = [GitClone]::new()
        $currentState.HttpsUrl = $this.HttpsUrl
        $currentState.RootDirectory = $this.RootDirectory
        $currentState.FolderName = $this.FolderName
        $currentState.Ensure = [Ensure]::Absent
        $currentState.RemoteName = ($null -eq $this.RemoteName) ? 'origin' : $this.RemoteName

        if (-not(Test-Path -Path $this.RootDirectory)) {
            return $currentState
        }

        # Check if the URL is a Git repository URL
        Assert-GitUrl -HttpsUrl $this.HttpsUrl

        Set-Location $this.RootDirectory
        $projectName = $this.FolderName ? $this.FolderName : (GetGitProjectName($this.HttpsUrl))
        $expectedDirectory = Join-Path -Path $this.RootDirectory -ChildPath $projectName

        if (Test-Path $expectedDirectory) {
            Set-Location -Path $expectedDirectory
            try {
                $gitRemoteValue = Invoke-GitRemote("get-url $($currentState.RemoteName)")
                if ($this.HttpsUrl.StartsWith($gitRemoteValue)) {
                    $currentState.Ensure = [Ensure]::Present
                }
            } catch {
                # Failed to execute `git remote`. Ensure state is `absent`
            }
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        if ($this.Ensure -eq [Ensure]::Absent) {
            throw 'This resource does not support removing a cloned repository.'
        }

        if (-not(Test-Path $this.RootDirectory)) {
            New-Item -ItemType Directory -Path $this.RootDirectory
        }

        Set-Location $this.RootDirectory
        
        if ($this.FolderName) {
            $cloneArgs = "$($this.HttpsUrl) $($this.FolderName)"
        } else {
            $cloneArgs = $this.HttpsUrl
        }
        
        Invoke-GitClone($cloneArgs)
    }
}

[DSCResource()]
class GitRemote {
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$RemoteName

    [DscProperty(Key)]
    [string]$RemoteUrl

    # The root directory where the project will be cloned to. (i.e. the directory where you expect to run `git clone`)
    [DscProperty(Mandatory)]
    [string]$ProjectDirectory

    [GitRemote] Get() {
        $currentState = [GitRemote]::new()
        $currentState.RemoteName = $this.RemoteName
        $currentState.RemoteUrl = $this.RemoteUrl
        $currentState.ProjectDirectory = $this.ProjectDirectory

        if (-not(Test-Path -Path $this.ProjectDirectory)) {
            throw 'Project directory does not exist.'
        }

        Set-Location $this.ProjectDirectory
        try {
            $gitRemoteValue = Invoke-GitRemote("get-url $($this.RemoteName)")
            $currentState.Ensure = ($gitRemoteValue -like $this.RemoteUrl) ? [Ensure]::Present : [Ensure]::Absent
        } catch {
            $currentState.Ensure = [Ensure]::Absent
        }

        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        Set-Location $this.ProjectDirectory

        if ($this.Ensure -eq [Ensure]::Present) {
            try {
                Invoke-GitRemote("add $($this.RemoteName) $($this.RemoteUrl)")
            } catch {
                throw 'Failed to add remote repository.'
            }
        } else {
            try {
                Invoke-GitRemote("remove $($this.RemoteName)")
            } catch {
                throw 'Failed to remove remote repository.'
            }
        }
    }
}

[DSCResource()]
class GitConfigUserName {
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$UserName

    [DscProperty()]
    [ConfigLocation]$ConfigLocation

    [DscProperty()]
    [string]$ProjectDirectory

    [GitConfigUserName] Get() {
        $currentState = [GitConfigUserName]::new()
        $currentState.UserName = $this.UserName
        $currentState.ConfigLocation = $this.ConfigLocation
        $currentState.ProjectDirectory = $this.ProjectDirectory

        if ($this.ConfigLocation -ne [ConfigLocation]::global -and $this.ConfigLocation -ne [ConfigLocation]::system) {
            # Project directory is not required for --global or --system configurations
            if ($this.ProjectDirectory) {
                if (Test-Path -Path $this.ProjectDirectory) {
                    Set-Location $this.ProjectDirectory
                } else {
                    throw 'Project directory does not exist.'
                }
            } else {
                throw 'Project directory parameter must be specified for non-system and non-global configurations.'
            }
        }

        $configArgs = ConstructGitConfigUserArguments -Arguments 'user.name' -ConfigLocation $this.ConfigLocation
        $result = Invoke-GitConfig($configArgs)
        $currentState.Ensure = ($currentState.UserName -eq $result) ? [Ensure]::Present : [Ensure]::Absent
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        if ($this.ConfigLocation -eq [ConfigLocation]::system) {
            Assert-IsAdministrator
        }

        if ($this.ConfigLocation -ne [ConfigLocation]::global -and $this.ConfigLocation -ne [ConfigLocation]::system) {
            Set-Location $this.ProjectDirectory
        }

        if ($this.Ensure -eq [Ensure]::Present) {
            $configArgs = ConstructGitConfigUserArguments -Arguments "user.name '$($this.UserName)'" -ConfigLocation $this.ConfigLocation
        } else {
            $configArgs = ConstructGitConfigUserArguments -Arguments '--unset user.name' -ConfigLocation $this.ConfigLocation
        }

        Invoke-GitConfig($configArgs)
    }
}

[DSCResource()]
class GitConfigUserEmail {
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$UserEmail

    [DscProperty()]
    [ConfigLocation]$ConfigLocation

    [DscProperty()]
    [string]$ProjectDirectory

    [GitConfigUserEmail] Get() {
        $currentState = [GitConfigUserEmail]::new()
        $currentState.UserEmail = $this.UserEmail
        $currentState.ConfigLocation = $this.ConfigLocation
        $currentState.ProjectDirectory = $this.ProjectDirectory

        if ($this.ConfigLocation -ne [ConfigLocation]::global -and $this.ConfigLocation -ne [ConfigLocation]::system) {
            # Project directory is not required for --global or --system configurations
            if ($this.ProjectDirectory) {
                if (Test-Path -Path $this.ProjectDirectory) {
                    Set-Location $this.ProjectDirectory
                } else {
                    throw 'Project directory does not exist.'
                }
            } else {
                throw 'Project directory parameter must be specified for non-system and non-global configurations.'
            }
        }

        $configArgs = ConstructGitConfigUserArguments -Arguments 'user.email' -ConfigLocation $this.ConfigLocation
        $result = Invoke-GitConfig($configArgs)
        $currentState.Ensure = ($currentState.UserEmail -eq $result) ? [Ensure]::Present : [Ensure]::Absent
        return $currentState
    }

    [bool] Test() {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set() {
        if ($this.ConfigLocation -eq [ConfigLocation]::system) {
            Assert-IsAdministrator
        }

        if ($this.ConfigLocation -ne [ConfigLocation]::global -and $this.ConfigLocation -ne [ConfigLocation]::system) {
            Set-Location $this.ProjectDirectory
        }

        if ($this.Ensure -eq [Ensure]::Present) {
            $configArgs = ConstructGitConfigUserArguments -Arguments "user.email $($this.UserEmail)" -ConfigLocation $this.ConfigLocation
        } else {
            $configArgs = ConstructGitConfigUserArguments -Arguments '--unset user.email' -ConfigLocation $this.ConfigLocation
        }

        Invoke-GitConfig($configArgs)
    }
}

#endregion DSCResources

#region Functions
function Assert-Git {
    # Refresh session $path value before invoking 'git'
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    try {
        Invoke-Git -Command 'help'
        return
    } catch {
        throw 'Git is not installed'
    }
}

function GetGitProjectName {
    param(
        [Parameter()]
        [string]$HttpsUrl
    )

    $projectName = ($HttpsUrl.split('/')[-1]).split('.')[0]
    return $projectName
}

function Invoke-GitConfig {
    param(
        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add('config')
    $command.Add($Arguments)
    return Invoke-Git -Command $command
}

function Invoke-GitRemote {
    param(
        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add('remote')
    $command.Add($Arguments)
    return Invoke-Git -Command $command
}

function Invoke-GitClone {
    param(
        [Parameter()]
        [string]$Arguments
    )

    $command = [List[string]]::new()
    $command.Add('clone')
    $command.Add($Arguments)
    return Invoke-Git -Command $command
}

function Invoke-Git {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return Invoke-Expression -Command "git $Command"
}

function ConstructGitConfigUserArguments {
    param(
        [Parameter(Mandatory)]
        [string]$Arguments,

        [Parameter(Mandatory)]
        [ConfigLocation]$ConfigLocation
    )

    $ConfigArguments = $Arguments
    if ([ConfigLocation]::None -ne $this.ConfigLocation) {
        $ConfigArguments = "--$($this.ConfigLocation) $($ConfigArguments)"
    }

    return $ConfigArguments
}

function Assert-IsAdministrator {
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object -TypeName 'System.Security.Principal.WindowsPrincipal' -ArgumentList @( $windowsIdentity )

    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

    if (-not $windowsPrincipal.IsInRole($adminRole)) {
        throw 'This resource must be run as an Administrator to modify system settings.'
    }
}

function Assert-GitUrl {
    param(
        [Parameter(Mandatory)]
        [string]$HttpsUrl
    )

    $out = Invoke-Git -Command "ls-remote $HttpsUrl *" 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Invalid Git URL: $HttpsUrl. Error: $out"
    }
}
#endregion Functions
