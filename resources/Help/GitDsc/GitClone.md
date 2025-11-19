---
external help file: GitDsc.psm1-Help.xml
Module Name: GitDsc
ms.date: 07/18/2025
online version:
schema: 2.0.0
title: GitClone
---

# GitClone

## SYNOPSIS

The `GitClone` DSC Resource allows you to clone Git repositories to a specified directory using the git CLI.

## DESCRIPTION

The `GitClone` DSC Resource allows you to clone Git repositories to a specified directory using the git CLI.
The resource ensures that the specified Git repository is cloned to the desired location and can optionally specify a custom folder name for the cloned repository.

## PARAMETERS

| **Parameter**   | **Attribute** | **DataType** | **Description**                                                                                                                              | **Allowed Values**   |
| --------------- | ------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| `HttpsUrl`      | Key           | String       | The HTTPS URL of the Git repository to clone. Must end with `.git` extension.                                                                | Should end with .git |
| `RootDirectory` | Mandatory     | String       | The root directory where the repository will be cloned to (i.e., the directory where you expect to run `git clone`).                         | N/A                  |
| `RemoteName`    | Optional      | String       | The name of the remote to use for the cloned repository. If not specified, defaults to `origin`.                                             | N/A                  |
| `FolderName`    | Optional      | String       | The folder name where the repository will be cloned to. If not specified, it will be derived from the HTTPS URL.                             | N/A                  |
| `ExtraArgs`     | Optional      | String       | The extra Arguments to be passed to `git clone`                                                                                              | N/A                  |
| `Ensure`        | Optional      | Ensure       | Indicates whether the repository should be cloned. Defaults to `Present`. Note: This resource does not support removing a cloned repository. | `Present`, `Absent`  |

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-DscResource -ModuleName GitDsc -Name GitClone -Method Get -Property @{ 
    HttpsUrl = 'https://github.com/microsoft/winget-dsc.git'
    RootDirectory = 'C:\repos'
}

# This example gets the current state of the Git repository 'winget-dsc' in the C:\repos directory.
```

### EXAMPLE 2

```powershell
Invoke-DscResource -ModuleName GitDsc -Name GitClone -Method Set -Property @{
    HttpsUrl = 'https://github.com/microsoft/winget-dsc.git'
    RootDirectory = 'C:\repos'
}

# This example clones the winget-dsc repository to C:\repos\winget-dsc.
```

### EXAMPLE 3

```powershell
Invoke-DscResource -ModuleName GitDsc -Name GitClone -Method Set -Property @{
    HttpsUrl = 'https://github.com/microsoft/winget-dsc.git'
    RootDirectory = 'C:\repos'
    FolderName = 'my-winget-dsc'
}

# This example clones the winget-dsc repository to C:\repos\my-winget-dsc with a custom folder name.
```

### EXAMPLE 4

```powershell
Invoke-DscResource -ModuleName GitDsc -Name GitClone -Method Set -Property @{
    HttpsUrl = 'https://github.com/microsoft/winget-dsc.git'
    RootDirectory = 'C:\repos'
    RemoteName = 'upstream'
}

# This example clones the winget-dsc repository with a custom remote name 'upstream' instead of the default 'origin'.
```

### EXAMPLE 5

```powershell
Invoke-DscResource -ModuleName GitDsc -Name GitClone -Method Set -Property @{
    HttpsUrl = 'https://github.com/microsoft/winget-dsc.git'
    RootDirectory = 'C:\repos'
    ExtraArgs = '--filter=blob:none --no-checkout'
}

# This example clones the winget-dsc repository but does not download any files.
```
