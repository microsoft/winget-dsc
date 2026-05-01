# Start developing WinUI apps

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) ([_winui-config.winget_](./winui-config.winget)) that will work with the WinGet command line interface (`winget configure --file [path: learn_winappdev.winget]`) or can be run directly by double-clicking on the file.

When run, the [winui-config.winget](./winui-config.winget) file will install the following list of applications:

- Microsoft Visual Studio Community 2026
- Required Visual Studio workloads for WinUI and Windows App SDK development

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Quick start: Set up your environment and create a WinUI project](https://learn.microsoft.com/windows/apps/get-started/start-here) Microsoft Learn tutorial.

## v3 Samples

A v3 version of each configuration is also available (e.g., `winui-config.v3.winget`) using the dscv3 processor syntax with explicit module installs.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
