# Get started building an app with Windows AI Foundry and App Actions

This folder contains [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration Files](https://learn.microsoft.com/windows/package-manager/configuration/) ([_learn_wcr.winget_](./learn_wcr.winget)) that will work with the WinGet command line interface (`winget configure --file [path: learn_wcr.winget]`) or can be run directly by double-clicking on the file.

When run, these files will install the dependencies needed for Windows AI APIs or App Actions on Windows.

AI APIs:
- Microsoft Visual Studio Community 2022
- Visual Studio Components: Universal, ManagedDesktop and Windows App SDK component group.

App Actions:
- Microsoft Visual Studio Community 2022
- Visual Studio Components: Universal, NativeDesktop or ManagedDesktop and MSIX.Packagingcomponent group

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Get started building an app with Windows AI APIs](https://learn.microsoft.com/windows/ai/apis/get-started) and [Get started with App Actions on Windows](https://learn.microsoft.com/en-us/windows/ai/app-actions/actions-get-started?tabs=winget) Microsoft Learn tutorials.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
