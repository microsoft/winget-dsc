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

    # DSCResource requires a key. Do not set.
    [DscProperty(Key)]
    [string]$SID

    # if not, then current directory is used.
    [DscProperty()]
    [string]$WorkingDirectory

    # If the root directory is not provided, then
    [DscProperty()]
    [bool]$RootDirectory

    [DscProperty(Mandatory)]
    [string]$HttpsUrl

    [GitClone] Get()
    {
        $currentState = [GitClone]::new()

        if (-not([string]::IsNullOrEmpty($this.RootDirectory)))
        {
            if (Test-Path -Path $this.RootDirectory -PathType Container)
            {
                Set-Location -Path $this.RootDirectory

                if (IsFolderWorkingTree)
                {
                    $currentState.Ensure = [Ensure]::Present
                }
                else
                {
                    $currentState.Ensure = [Ensure]::Absent
                }
            }
            else
            {
                $currentState.Ensure = [Ensure]::Absent
            }
        }

        if (-not([string]::IsNullOrEmpty($this.WorkingDirectory)))
        {
            if (Test-Path -Path $this.WorkingDirectory -PathType Container)
            {
                Set-Location -Path $this.WorkingDirectory

                $projectName = GetGitProjectName($this.HttpsUrl)
                $expectedProjectDir = Join-Path -Path $this.WorkingDirectory -ChildPath $projectName

                if (Test-Path -Path $expectedProjectDir -PathType Container)
                {
                    Set-Location -Path $expectedProjectDir
                    if (IsFolderWorkingTree)
                    {
                        $currentState.Ensure = [Ensure]::Present
                    }        
                    else
                    {
                        $currentState.Ensure = [Ensure]::Absent
                    }
                }
                else
                {
                    $currentState.Ensure = [Ensure]::Absent
                }
            }
            else
            {
                throw exception
            }
        }
        # if the root directory does not exist then ensure is absent

        # if the root directory does exist, check using git is working tree and see if it returns true or false.

        # If no root directory is provided, use the current working directory, check if the folder exists based on the provided httpsurl

        # if the folder exists, then cd and check if it is a git working tree
        # if not, then return absent

        # if the folder does not exist then return absent.


        if (-not([string]::IsNullOrEmpty($this.WorkingDirectory)))
        {
            if (Test-Path -Path $this.WorkingDirectory -PathType Container)
            {
                Set-Location -Path $this.WorkingDirectory
            }
            elseif ($this.CreateWorkingDirectory)
            {
                New-Item -Path $this.WorkingDirectory -ItemType Directory
            }
            else
            {
                throw "$($this.WorkingDirectory) does not point to a valid working directory."
            }
        }

        
        $currentState = [Ensure]::Present



        $currentState.WorkingDirectory = $this.WorkingDirectory
        $currentState.Arguments = $this.Arguments
        $currentState.PackageDirectory = $this.PackageDirectory
        return $currentState;
    }

    [bool] Test()
    {
        # check if the folder already exists
        # Yarn install is inherently idempotent as it will also resolve package dependencies. Set to $false
        return $false
    }

    [void] Set()
    {
        $currentState = $this.Get()
        Invoke-YarnInstall -Arguments $currentState.Arguments
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

function IsFolderWorkingTree
{
    $command = [List[string]]::new()
    $command.Add("rev-parse --is-inside-work-tree")
    try {
        return (Invoke-Git -Command) -eq 'true'
    }
    catch {
        # do nothing
    }

    return false
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