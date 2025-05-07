# Get started building an app with Windows Copilot Runtime APIs

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) ([_learn_wcr.winget_](./learn_wcr.winget)) that will work with the WinGet command line interface (`winget configure --file [path: learn_wcr.winget]`) or can be run directly by double-clicking on the file.

When run, the [learn_wcr.winget](./learn_wcr.winget) file will install the following list of applications:

- Microsoft Visual Studio Community 2022
- Visual Studio Components: Universal, ManagedDesktop and Windows App SDK component group.

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Get started building an app with Windows Copilot Runtime APIs](https://learn.microsoft.com/windows/ai/apis/get-started) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
