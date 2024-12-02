---
title: WinGet Desired State Configuration
description: WinGet Desired State Configuration (DSC) consist out of PowerShell class-based DSC resources targeting PowerShell 7.2+. Each module exposes classes that can be invoked through multiple tools
ms.date: 10/23/2024
ms.topic: overview
---

WinGet Desired State Configuration (DSC) consist out of PowerShell class-based DSC resources targeting PowerShell 7.2+. Each module exposes classes that help you configure your machine in the desired state. The DSC resources is developed around the `Get-Test-Set` methods. If applicable, the team attempts to implement new methods known to newer versions of DSC.

> To learn more about the newer DSC version, check out <https://learn.microsoft.com/en-us/powershell/dsc/overview?view=dsc-3.0>

## Getting started

To get started, you can find the available published modules on the [PowerShell Gallery](https://www.powershellgallery.com/profiles/DscSamples). If you have found your module, you can install it with:

```powershell
$moduleName = '<moduleName>'
Install-PSResource -Name $moduleName -Repository PSGallery
```

Use the following commands to list out the exported DSC resources from the module or use `Get-DscResource` to discover properties:

```powershell
# discover exported DSC resources
(Get-Module -Name $moduleName -ListAvailable).ExportedDscResources

# find available properties
Get-DscResource -Module $moduleName
```
