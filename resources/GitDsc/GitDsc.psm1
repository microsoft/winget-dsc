# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

using namespace System.Collections.Generic

enum Ensure
{
    Absent
    Present
}

# Assert once that Git is already installed on the system.
Assert-Git

#region DSCResources
[DSCResource()]
class GitClone
{
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$HttpsUrl

    [DscProperty()]
    [string]$RemoteName

    # The root directory where the project will be cloned to. (i.e. the directory where you expect to run `git clone`)
    [DscProperty(Mandatory)]
    [string]$RootDirectory

    [GitClone] Get()
    {
        $currentState = [GitClone]::new()
        $currentState.HttpsUrl = $this.HttpsUrl
        $currentState.RootDirectory = $this.RootDirectory
        $currentState.Ensure = [Ensure]::Absent
        $currentState.RemoteName = ($null -eq $this.RemoteName) ? "origin" : $this.RemoteName

        if (-not(Test-Path -Path $this.RootDirectory))
        {
            return $currentState
        }

        Set-Location $this.RootDirectory
        $projectName = GetGitProjectName($this.HttpsUrl)
        $expectedDirectory = Join-Path -Path $this.RootDirectory -ChildPath $projectName

        if (Test-Path $expectedDirectory)
        {
            Set-Location -Path $expectedDirectory
            try 
            {
                $gitRemoteValue = Invoke-GitRemote("get-url $($currentState.RemoteName)")
                if ($gitRemoteValue -like $this.HttpsUrl)
                {
                    $currentState.Ensure = [Ensure]::Present
                }
            }
            catch
            {
                # Failed to execute `git remote`. Ensure state is `absent`
            }
        }

        return $currentState;
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set()
    {
        if ($this.Ensure -eq [Ensure]::Absent)
        {
            throw "This resource does not support removing a cloned repository."
        }

        if (-not(Test-Path $this.RootDirectory))
        {
            New-Item -ItemType Directory -Path $this.RootDirectory
        }

        Set-Location $this.RootDirectory
        Invoke-GitClone($this.HttpsUrl)
    }
}

[DSCResource()]
class GitRemote
{
    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    [DscProperty(Key)]
    [string]$RemoteName

    [DscProperty(Key)]
    [string]$RemoteUrl

    # The root directory where the project will be cloned to. (i.e. the directory where you expect to run `git clone`)
    [DscProperty(Mandatory)]
    [string]$ProjectDirectory

    [GitRemote] Get()
    {
        $currentState = [GitRemote]::new()
        $currentState.RemoteName = $this.RemoteName
        $currentState.RemoteUrl = $this.RemoteUrl
        $currentState.ProjectDirectory = $this.ProjectDirectory

        if (-not(Test-Path -Path $this.ProjectDirectory))
        {
            throw "Project directory does not exist."
        } 

        Set-Location $this.ProjectDirectory
        try
        {
            $gitRemoteValue = Invoke-GitRemote("get-url $($this.RemoteName)")
            $currentState.Ensure = ($gitRemoteValue -like $this.RemoteUrl) ? [Ensure]::Present : [Ensure]::Absent
        }
        catch
        {
            $currentState.Ensure = [Ensure]::Absent
        }

        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()
        return $currentState.Ensure -eq $this.Ensure
    }

    [void] Set()
    {
        Set-Location $this.ProjectDirectory

        if ($this.Ensure -eq [Ensure]::Present)
        {
            try
            {
                Invoke-GitRemote("add $($this.RemoteName) $($this.RemoteUrl)")
            }
            catch
            {
                throw "Failed to add remote repository."
            }
        }
        else
        {
            try
            {
                Invoke-GitRemote("remove $($this.RemoteName)")
            }
            catch
            {
                throw "Failed to remove remote repository."
            }
        }
    }
}

#endregion DSCResources

#region Functions
function Assert-Git
{
    # Refresh session $path value before invoking 'git'
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    try
    {
        Invoke-Git -Command 'help'
        return
    }
    catch
    {
        throw "Git is not installed"
    }
}

function GetGitProjectName
{
    param(
        [Parameter()]
        [string]$HttpsUrl       
    )

    $projectName = ($HttpsUrl.split('/')[-1]).split('.')[0]
    return $projectName
}

function Invoke-GitRemote
{
    param(
        [Parameter()]
        [string]$Arguments       
    )

    $command = [List[string]]::new()
    $command.Add("remote")
    $command.Add($Arguments)
    return Invoke-Git -Command $command 
}

function Invoke-GitClone
{
    param(
        [Parameter()]
        [string]$Arguments       
    )

    $command = [List[string]]::new()
    $command.Add("clone")
    $command.Add($Arguments)
    return Invoke-Git -Command $command
}

function Invoke-Git
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    return Invoke-Expression -Command "git $Command"
}

#endregion Functions