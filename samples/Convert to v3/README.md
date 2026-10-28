# Converting WinGet Configuration Files from v2 to v3

This guide covers how to convert WinGet configuration files from the DSC v2 schema (`configuration-dsc-schema/0.2`) to the dscv3 processor syntax (v3).

## Why Convert to v3?

The dscv3 processor brings several improvements:

- **Native v3 resources** — Resources like `Microsoft.Windows/Registry` are dramatically faster (~3 seconds per key vs 89–228 seconds with the adapted `PSDscResources/Registry`)
- **Modern DSC runtime** — Built on DSC v3, which provides better resource discovery and execution
- **Explicit dependency management** — Module installs are declared as resources, making configurations self-contained and reproducible

## Prerequisites

- **WinGet v1.28+** with DSC v3 support
- **DSC v3** installed on the system
- **PowerShell 7** for module installs and script resources

## Quick Reference

### Document Structure

**v2:**

```yaml
# yaml-language-server: $schema=https://aka.ms/configuration-dsc-schema/0.2
properties:
  configurationVersion: 0.2.0
  resources:
    - resource: ...
```

**v3:**

```yaml
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2023/08/config/document.json
metadata:
  winget:
    processor:
      identifier: dscv3
resources:
- type: ...
```

### Field Renaming

| v2 Field | v3 Field |
|----------|----------|
| `resource:` | `type:` |
| `id:` | `name:` (PascalCase) |
| `settings:` | `properties:` |
| `directives:` | `metadata:` |

### Resource Type Mapping

| v2 Resource Type | v3 Resource Type | Notes |
|------------------|------------------|-------|
| `Microsoft.WinGet.DSC/WinGetPackage` | `Microsoft.WinGet/Package` | Add `useLatest: true` to properties |
| `PSDscResources/Registry` | `Microsoft.Windows/Registry` | **Use native v3 resource — dramatically faster** |
| `PSDscResources/Script` | `Microsoft.DSC.Transitional/RunCommandOnSet` | Or `PowerShellScript` / `WindowsPowerShellScript` |
| `Microsoft.Windows.Developer/*` | `Microsoft.Windows.Developer/*` | Unchanged type, but requires explicit module install |
| `Microsoft.Windows.Settings/*` | `Microsoft.Windows.Settings/*` | Unchanged type, but requires explicit module install |
| `Microsoft.VisualStudio.DSC/*` | `Microsoft.VisualStudio.DSC/*` | Unchanged type, but requires explicit module install |
| `Microsoft.VSCode.Dsc/*` | `Microsoft.VSCode.Dsc/*` | Unchanged type, but requires explicit module install |

### Security Context

In v2, elevation is in `directives.securityContext`. In v3, it moves to `metadata.winget.securityContext`:

```yaml
  metadata:
    winget:
      securityContext: elevated
    description: ...
```

### Module Installs

In v3, adapted PowerShell DSC resources require explicit module installation. Use `Install-PSResource` (ships with PowerShell 7):

```yaml
- type: Microsoft.DSC.Transitional/RunCommandOnSet
  name: Microsoft.Windows.Developer.Module
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

> **Note:** Only use `-Prerelease` when no stable version exists on the PowerShell Gallery. Check with `Find-PSResource -Name <ModuleName>`.

### Registry Resources

**Always convert `PSDscResources/Registry` to native `Microsoft.Windows/Registry`.** This is the single highest-impact optimization.

**v2:**

```yaml
- resource: PSDscResources/Registry
  id: sudo
  directives:
    description: Enable Sudo
    securityContext: elevated
  settings:
    Key: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo
    ValueName: Enabled
    ValueType: DWord
    ValueData: '3'
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
    description: Enable Sudo
```

Key differences:
- Path format: `HKLM\...` (no colon, no PowerShell drive notation)
- Value data uses typed objects: `{ DWord: 3 }`, `{ String: "text" }`, `{ QWord: 0 }`
- `Ensure: Present` becomes `_exist: true`
- No `Force:` property needed
- No module install dependency needed
- `HKLM\` keys need `securityContext: elevated`; `HKCU\` keys do not

## Conversion Checklist

- [ ] Update document structure (`$schema`, `metadata.winget.processor`, remove `properties:` wrapper)
- [ ] Rename all fields (`resource`→`type`, `id`→`name`, `settings`→`properties`, `directives`→`metadata`)
- [ ] Update resource type names (`Microsoft.WinGet.DSC/WinGetPackage` → `Microsoft.WinGet/Package`)
- [ ] Add `useLatest: true` to all package resources
- [ ] Check each package's WinGet manifest for `ElevationRequirement` before adding `securityContext: elevated`
- [ ] **Convert all `PSDscResources/Registry` to native `Microsoft.Windows/Registry`**
- [ ] Add module install resources for adapted class-based DSC resources
- [ ] Use `Install-PSResource` (not `Install-Module`) for module installs
- [ ] Check PowerShell Gallery for each module — only use `-Prerelease` when no stable version exists
- [ ] Add `dependsOn` from each adapted resource to its module install resource
- [ ] Convert `PSDscResources/Script` to `RunCommandOnSet` (or script alternatives)
- [ ] Update `dependsOn` references to use PascalCase `name:` values
- [ ] Apply `securityContext: elevated` only where truly required
- [ ] Remove `allowPrerelease: true` from resource metadata (v2 directive, not used in v3)
- [ ] Remove `PSDscResources.Module` install if all Registry resources use native v3

## Using the Copilot CLI Skill

A [GitHub Copilot CLI](https://docs.github.com/copilot/github-copilot-in-the-cli) skill is included in this folder to automate the conversion process. The skill teaches Copilot the complete set of v2 → v3 conversion rules.

### Installation

Copy the skill file to your Copilot CLI skills directory:

```powershell
# Create the skill directory
New-Item -ItemType Directory -Path "$HOME/.copilot/skills/winget-config-v2-to-v3" -Force

# Copy the skill file (run from the samples/Convert to v3 directory of this repo)
Copy-Item "./SKILL.md" "$HOME/.copilot/skills/winget-config-v2-to-v3/SKILL.md"
```

### Usage

Once installed, invoke the skill in Copilot CLI by referencing it in your prompt:

```
Convert this v2 WinGet configuration file to v3: <paste or reference file>
```

The skill will automatically apply all conversion rules including:
- Document structure changes
- Field renaming
- Resource type mapping
- Native registry resource conversion
- Module install generation
- Elevation rules
- Performance optimizations

### Skill Updates

The skill file (`SKILL.md`) in this folder is the canonical version. If conversion rules change, update this file and re-copy it to your skills directory.

## Performance Considerations

| Resource Type | Approx. Eval Cost | Scaling |
|---------------|-------------------|---------|
| `Microsoft.Windows/Registry` (native v3) | **~3s each** | **Linear** |
| `RunCommandOnSet` / Script variants | ~5s each | Linear |
| `Microsoft.WinGet/Package` | ~8–16s each | Linear |
| `Microsoft.Windows.Settings/*` (adapted) | ~95s each | Variable |
| `Microsoft.Windows.Developer/*` (adapted) | ~30–122s each | Super-linear |
| `PSDscResources/Registry` (adapted) | ~89–228s each | **Super-linear — avoid** |

Fixed overhead for dscv3 processor startup: ~23 seconds.

## Examples

See the [DscResources](../DscResources/) and [Learn tutorials](../Configuration%20files/Learn%20tutorials/) directories for side-by-side v2 (`*.winget`) and v3 (`*.v3.winget`) sample configurations.
