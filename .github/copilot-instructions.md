# WinGet DSC Development Guide

## Project Overview

This repository contains **Desired State Configuration (DSC) v3 resources** used with WinGet Configuration. Resources here are largely class-based PowerShell modules, each targeting a specific tool or Windows setting area:

- **`resources/GitDsc`** - Git configuration/clone resource
- **`resources/Microsoft.DotNet.Dsc`** - .NET SDK/tooling resources
- **`resources/Microsoft.VSCode.Dsc`** - VS Code extension/settings resources
- **`resources/Microsoft.Windows.Developer`** - Windows developer-mode settings
- **`resources/Microsoft.Windows.Setting.Accessibility`** - Windows accessibility settings
- **`resources/Microsoft.Windows.Settings`** - General Windows settings resources
- **`resources/Microsoft.WindowsSandbox.DSC`** - Windows Sandbox configuration
- **`resources/NpmDsc`**, **`resources/PythonPip3Dsc`**, **`resources/RustDsc`**, **`resources/YarnDsc`** - Package-manager-specific resources
- **`resources/Help`** - Generated/authored help content (synopsis + examples) for each resource
- **`samples/`** - Example WinGet Configuration YAML files using these resources (also published at `https://aka.ms/dsc.yaml`)
- **`doc/`** - Design docs and specs for resources

## Resource Structure

Each resource module typically ships:
- A `.psd1` module manifest and `.psm1`/class-based implementation
- A DSC v3 resource manifest (`*.dsc.resource.json`) so `dsc resource list` can discover it without invoking the PowerShell adapter for metadata
- Pester tests under a `tests/` folder alongside the resource

Some resources here are **exploratory** and may never ship to the PowerShell Gallery, may move to their own repos, or may be removed — check `doc/` and open issues before assuming a resource is stable.

## Building, Testing, and Running

- These are pure PowerShell modules — no compiled build step. Import a resource directly with `Import-Module .\resources\<Resource>\<Resource>.psd1` for local testing.
- Run resource tests with Pester: `Invoke-Pester` from the resource's test directory.
- Test end-to-end with `winget configure` and a sample from `samples/`, or directly with `dsc resource test/get/set -r <ResourceName>`.

## Conventions

- Follow the naming pattern `<Vendor>.<Tool>.Dsc` (e.g., `NpmDsc`, `GitDsc`) or `Microsoft.<Area>.<Subarea>` for Microsoft/Windows-owned settings resources.
- Prefer **adapted resource manifests** (`*.dsc.adaptedResource.json`) for new/updated resources so DSC v3 can discover them without spawning PowerShell — see tracking issue [microsoft/winget-dsc#272](https://github.com/microsoft/winget-dsc/issues/272).
- Keep resource `Help/` content (synopsis + examples) in sync with schema/parameter changes.

## Contributing

- Review `CONTRIBUTING.md` (root) for workflow and CLA requirements.
- New resources or significant changes should be discussed via an issue first, referencing `doc/specs` where applicable.
- CI runs via Azure Pipelines (`pipelines/`).
