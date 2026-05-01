---
name: winget-config-v2-to-v3
description: >
  Converts WinGet Configuration files from DSC schema v0.2 (v2) to the dscv3 processor
  syntax (v3). Use this skill when asked to convert, migrate, or upgrade a WinGet
  Configuration file from v2 to v3, or when working with .winget configuration files
  that need to be updated to the dscv3 schema.
---

# WinGet Configuration v2 → v3 Conversion Skill

You are an expert at converting WinGet Configuration files from DSC schema v0.2 (v2) to
the dscv3 processor syntax (v3). Follow these rules precisely.

## Document Structure

### v2 structure

```yaml
# yaml-language-server: $schema=https://aka.ms/configuration-dsc-schema/0.2
properties:
  configurationVersion: 0.2.0
  assertions:
    - resource: ...
  resources:
    - resource: ...
```

### v3 structure

```yaml
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2023/08/config/document.json
metadata:
  winget:
    processor:
      identifier: dscv3
resources:
- type: ...
```

**Key changes:**
- Remove the `properties:` wrapper and `configurationVersion`
- Remove `assertions:` section (v3 does not support assertions in the same way)
- Add `$schema` pointing to the DSC v3 schema
- Add `metadata.winget.processor.identifier: dscv3`
- Resources move to a top-level `resources:` array

## Field Renaming

Apply these renames to every resource:

| v2 Field | v3 Field |
|----------|----------|
| `resource:` | `type:` |
| `id:` | `name:` |
| `settings:` | `properties:` |
| `directives:` | `metadata:` |

### Example

**v2:**
```yaml
- resource: Microsoft.WinGet.DSC/WinGetPackage
  id: git
  directives:
    description: Install Git
    allowPrerelease: true
  settings:
    id: Git.Git
    source: winget
```

**v3:**
```yaml
- type: Microsoft.WinGet/Package
  name: Git
  properties:
    id: Git.Git
    source: winget
    useLatest: true
  metadata:
    description: Install Git
```

## Resource Type Mapping

| v2 Resource Type | v3 Resource Type | Notes |
|------------------|------------------|-------|
| `Microsoft.WinGet.DSC/WinGetPackage` | `Microsoft.WinGet/Package` | Renamed |
| `PSDscResources/Registry` | **`Microsoft.Windows/Registry`** | **Use native v3 resource — dramatically faster** |
| `PSDscResources/Script` | `Microsoft.DSC.Transitional/RunCommandOnSet` | Or `PowerShellScript`/`WindowsPowerShellScript` if test support needed |
| `Microsoft.Windows.Developer/*` | `Microsoft.Windows.Developer/*` | Unchanged (adapted resource, requires module install) |
| `Microsoft.Windows.Settings/*` | `Microsoft.Windows.Settings/*` | Unchanged (adapted resource, requires module install) |

**CRITICAL: Always prefer `Microsoft.Windows/Registry` over `PSDscResources/Registry`.**
The native v3 resource evaluates in ~3 seconds per key with linear scaling. The adapted
`PSDscResources/Registry` takes 89–228 seconds per key with super-linear growth. For a
configuration with 22 registry keys, this is the difference between ~2 minutes and 30+ minutes.
Using the native resource also eliminates the need to install the PSDscResources module.

## Package Resources (`Microsoft.WinGet/Package`)

### Properties changes

- Add `useLatest: true` to properties (replaces the concept of always getting latest)
- Remove `allowPrerelease: true` from directives/metadata (this was a v2 directive)
- The `source: winget` property remains the same

### Security Context / Elevation

**CRITICAL: Do NOT blindly add `securityContext: elevated` to package installs.**

Before adding `securityContext: elevated` to any package resource, check the package's
installer manifest in the `microsoft/winget-pkgs` repository for the `ElevationRequirement` field:

- `elevationRequired` → **Yes**, add `securityContext: elevated`
- `elevatesSelf` → **No**, the installer handles its own UAC prompt
- No `ElevationRequirement` field → **No**, elevation is not needed
- Portable/zip installers → **No**, never need elevation
- MSIX installers → **No**, never need elevation

To check, look up the installer manifest at:
`manifests/<first-letter>/<Publisher>/<Package>/<Version>/<Id>.installer.yaml`

When elevation IS needed, add it in metadata:

```yaml
  metadata:
    winget:
      securityContext: elevated
    description: ...
```

### Common packages and their elevation requirements

| Package | ElevationRequirement | Needs elevated? |
|---------|---------------------|-----------------|
| Git.Git | elevatesSelf | No |
| GitHub.Cli | elevatesSelf | No |
| GitHub.Copilot | None (portable) | No |
| Microsoft.PowerShell | elevatesSelf (MSI) | No |
| Microsoft.VisualStudioCode | None | No |
| Python.Python.3.x | elevatesSelf (machine) | No |
| astral-sh.uv | None (portable) | No |
| OpenJS.NodeJS | elevatesSelf | No |
| JanDeDobbeleer.OhMyPosh | None (MSIX) | No |
| Microsoft.PowerToys | elevatesSelf (machine) | No |
| Microsoft.WSL | None | No |
| Canonical.Ubuntu | None (MSIX) | No |

## Class-Based DSC Resources (PowerShell Modules)

In v2, PowerShell class-based DSC resources (like `PSDscResources/Registry`,
`Microsoft.Windows.Developer/*`, `Microsoft.Windows.Settings/*`) are handled
automatically by the WinGet DSC processor.

In v3, the dscv3 processor does NOT know about v2-style PowerShell DSC resources.
You must **explicitly install the PowerShell modules** using
`Microsoft.DSC.Transitional/RunCommandOnSet` before any resources that depend on them.

### Required module installs

For each PowerShell DSC module used, add a RunCommandOnSet resource that installs it.
All module installs depend on PowerShell 7 being installed first.

**CRITICAL: Only use `-AllowPrerelease` when no stable version exists on the PowerShell Gallery.**

Check the PowerShell Gallery before adding `-Prerelease`:

```powershell
Find-PSResource -Name <ModuleName>                # Check for stable
Find-PSResource -Name <ModuleName> -Prerelease    # Check for prerelease
```

### Known module status (verify before use — this may change)

| Module | Stable Available? | Needs `-AllowPrerelease`? |
|--------|------------------|--------------------------|
| PSDscResources | Yes (2.12.0.0) | **No** |
| Microsoft.Windows.Settings | No (alpha only) | **Yes** |
| Microsoft.Windows.Developer | No (alpha only) | **Yes** |

### Module install pattern

Use `Install-PSResource` (built into PowerShell 7) rather than the older `Install-Module`:

```yaml
- type: Microsoft.DSC.Transitional/RunCommandOnSet
  name: Microsoft.Windows.Developer.Module
  dependsOn:
  - PowerShell
  properties:
    executable: C:\Program Files\PowerShell\7\pwsh.exe
    arguments:
      "0": -NoProfile
      "1": -NoLogo
      "2": -Command
      "3": >-
        if (-not (Get-Module -ListAvailable -Name Microsoft.Windows.Developer))
        { Install-PSResource -Name Microsoft.Windows.Developer -Prerelease
        -TrustRepository -AcceptLicense }
      treatAsArray: true
  metadata:
    description: Ensure Microsoft.Windows.Developer module is installed
```

For modules with a stable release (no `-Prerelease` flag needed):

```yaml
      "3": >-
        if (-not (Get-Module -ListAvailable -Name PSDscResources))
        { Install-PSResource -Name PSDscResources
        -TrustRepository -AcceptLicense }
```

### Dependency chain

Resources using these modules MUST have `dependsOn` pointing to the module install resource:

```yaml
- type: Microsoft.Windows.Developer/EnableLongPathSupport
  name: LongPaths
  dependsOn:
  - Microsoft.Windows.Developer.Module
  properties:
    Ensure: Present
  metadata:
    winget:
      securityContext: elevated
    description: Enable Win32 long paths
```

## PSDscResources/Script → RunCommandOnSet

v2 `PSDscResources/Script` resources have `GetScript`, `TestScript`, and `SetScript` blocks.
In v3, these become `Microsoft.DSC.Transitional/RunCommandOnSet` which only runs
the set logic. Combine the test and set logic into the command argument.

> **Alternative:** If you need proper test/get/set separation, use
> `Microsoft.DSC.Transitional/PowerShellScript` (runs in pwsh 7) or
> `Microsoft.DSC.Transitional/WindowsPowerShellScript` (runs in Windows PowerShell 5.1).
> These have `getScript`, `testScript`, and `setScript` properties and can properly report
> whether the system is already in the desired state. Performance is comparable to RunCommandOnSet.

### Example conversion

**v2:**
```yaml
- resource: PSDscResources/Script
  id: ps7default
  dependsOn:
    - powershell
  directives:
    description: Set PowerShell 7 as default Windows Terminal profile
  settings:
    GetScript: |
      return @{ Result = $false }
    TestScript: |
      # test logic here
      return $false
    SetScript: |
      # set logic here
```

**v3:**
```yaml
- type: Microsoft.DSC.Transitional/RunCommandOnSet
  name: ps7default
  dependsOn:
  - PowerShell
  properties:
    executable: C:\Program Files\PowerShell\7\pwsh.exe
    arguments:
      "0": -NoProfile
      "1": -NoLogo
      "2": -Command
      "3": |
        # Combined test + set logic here
      treatAsArray: true
  metadata:
    description: Set PowerShell 7 as default Windows Terminal profile
```

## Registry Resources — Use Native `Microsoft.Windows/Registry`

**CRITICAL: Convert all `PSDscResources/Registry` to `Microsoft.Windows/Registry`.**

The native v3 resource is a completely different (and far superior) resource:
- No PowerShell module install needed
- No adapter overhead
- ~3 seconds per key vs 89–228 seconds
- Linear scaling vs super-linear growth

### Property mapping

| v2 (`PSDscResources/Registry`) | v3 (`Microsoft.Windows/Registry`) | Notes |
|-------------------------------|----------------------------------|-------|
| `Key: HKLM:\SOFTWARE\...` | `keyPath: HKLM\SOFTWARE\...` | Drop the `:\` — use `HKLM\` not `HKLM:\` |
| `Key: HKCU:\SOFTWARE\...` | `keyPath: HKCU\SOFTWARE\...` | Drop the `:\` — use `HKCU\` not `HKCU:\` |
| `ValueName: Name` | `valueName: Name` | camelCase |
| `ValueType: DWord` + `ValueData: '3'` | `valueData: { DWord: 3 }` | Type is embedded in the data object |
| `ValueType: String` + `ValueData: text` | `valueData: { String: "text" }` | Type is embedded in the data object |
| `ValueType: QWord` + `ValueData: '0'` | `valueData: { QWord: 0 }` | Type is embedded in the data object |
| `Ensure: Present` | `_exist: true` | Different existence model |
| `Ensure: Absent` | `_exist: false` | Different existence model |
| `Force: true` | *(not needed)* | Native resource handles this |
| `dependsOn: [PSDscResources.Module]` | *(not needed)* | No module dependency |

### Conversion example

**v2:**
```yaml
- resource: PSDscResources/Registry
  id: sudo
  directives:
    description: Enable Sudo in inline mode
    allowPrerelease: true
    securityContext: elevated
  settings:
    Key: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo
    ValueName: Enabled
    ValueType: DWord
    ValueData: '3'
    Force: true
    Ensure: Present
```

**v3:**
```yaml
- type: Microsoft.Windows/Registry
  name: Sudo
  properties:
    keyPath: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo
    valueName: Enabled
    valueData:
      DWord: 3
    _exist: true
  metadata:
    winget:
      securityContext: elevated
    description: Enable Sudo in inline mode
```

### Value data types

| Registry Type | v3 Format | Example |
|--------------|-----------|---------|
| DWord | `valueData: { DWord: 3 }` | 32-bit integer |
| QWord | `valueData: { QWord: 0 }` | 64-bit integer |
| String | `valueData: { String: "text" }` | String value |
| ExpandString | `valueData: { ExpandString: "%PATH%" }` | Expandable string |
| MultiString | `valueData: { MultiString: ["a", "b"] }` | Array of strings |
| Binary | `valueData: { Binary: [0, 1, 2] }` | Array of bytes |
| None | `valueData: None` | No data |

### Elevation rules for Registry

- `HKLM\` keys → add `metadata.winget.securityContext: elevated`
- `HKCU\` keys → no elevation needed

## Security Context in v3

In v2, elevation was specified per-resource in `directives.securityContext`.

In v3, elevation is specified in `metadata.winget.securityContext`:

```yaml
  metadata:
    winget:
      securityContext: elevated
    description: ...
```

Resources that typically need elevation:
- Registry keys under `HKLM:\`
- `Microsoft.Windows.Developer/EnableLongPathSupport`
- `Microsoft.Windows.Developer/EnableRemoteDesktop`
- `Microsoft.Windows.Developer/UserAccessControl`
- `Microsoft.Windows.Settings/WindowsSettings` (for DeveloperMode)

Resources that typically do NOT need elevation:
- Registry keys under `HKCU:\`
- `Microsoft.Windows.Developer/WindowsExplorer`
- `Microsoft.Windows.Developer/Taskbar`
- Most `Microsoft.WinGet/Package` installs (check manifest first)

## Name Casing Convention

In v2, resource `id:` values are typically lowercase (e.g., `git`, `vscode`, `powershell`).

In v3, resource `name:` values should use PascalCase (e.g., `Git`, `VSCode`, `PowerShell`).

## Dependencies

`dependsOn` references must use the v3 `name:` value (PascalCase), not the v2 `id:` value.

**v2:** `dependsOn: [git]`
**v3:** `dependsOn: [Git]`

## Performance Considerations

When converting, be aware of the evaluation time costs of different resource types:

| Resource Type | Approx. Eval Cost | Scaling | Notes |
|---------------|-------------------|---------|-------|
| `Microsoft.WinGet/Package` | ~8–16s each | Linear | Efficient native resource |
| `RunCommandOnSet` | ~5s each | Linear | Lightweight |
| `PowerShellScript` / `WindowsPowerShellScript` | ~5s each | Linear | Same cost as RunCommandOnSet, but supports test |
| `Microsoft.Windows/Registry` (native v3) | **~3s each** | **Linear** | **Preferred for all registry operations** |
| `Microsoft.Windows.Settings/*` (adapted) | ~95s each | Variable | Class-based, requires adapter |
| `Microsoft.Windows.Developer/*` (adapted) | ~30–122s each | Super-linear | Expensive, especially when elevated |
| `PSDscResources/Registry` (adapted) | ~89–228s each | **Super-linear** | **Avoid — use `Microsoft.Windows/Registry` instead** |

Fixed overhead for dscv3 processor startup is approximately 23 seconds.

> **Key optimization:** Replacing `PSDscResources/Registry` with `Microsoft.Windows/Registry`
> is the single highest-impact optimization when converting a v2 config to v3. A config with
> 22 registry keys drops from 30+ minutes to under 2 minutes for registry evaluation alone.
> This also eliminates the need to install the PSDscResources PowerShell module.

## Conversion Checklist

When converting a v2 configuration to v3:

1. ☐ Update document structure (`$schema`, `metadata.winget.processor`, remove `properties:` wrapper)
2. ☐ Rename all fields (`resource`→`type`, `id`→`name`, `settings`→`properties`, `directives`→`metadata`)
3. ☐ Update resource type names (`Microsoft.WinGet.DSC/WinGetPackage` → `Microsoft.WinGet/Package`)
4. ☐ Add `useLatest: true` to all package resources
5. ☐ Check each package's WinGet manifest for `ElevationRequirement` before adding `securityContext: elevated`
6. ☐ **Convert all `PSDscResources/Registry` to native `Microsoft.Windows/Registry`** (key path format, valueData typed objects, `_exist` instead of `Ensure`)
7. ☐ Add PowerShell module install resources for any remaining adapted class-based DSC resources (Settings, Developer)
8. ☐ Use `Install-PSResource` (not `Install-Module`) for module installs — it ships with PowerShell 7
9. ☐ Check PowerShell Gallery for each module — only use `-Prerelease` when no stable version exists
10. ☐ Add `dependsOn` from each adapted resource to its module install resource
11. ☐ Convert `PSDscResources/Script` to `RunCommandOnSet` (or `PowerShellScript`/`WindowsPowerShellScript` if test support is needed)
12. ☐ Update `dependsOn` references to use PascalCase `name:` values
13. ☐ Apply `securityContext: elevated` only to HKLM registry keys and system-level settings that require it
14. ☐ Remove `allowPrerelease: true` from resource metadata (v2 directive, not used in v3)
15. ☐ Remove `PSDscResources.Module` install resource if all Registry resources are converted to native v3
