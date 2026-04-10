# Create a simple C# console app in Visual Studio

This folder contains [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration Files](https://learn.microsoft.com/windows/package-manager/configuration/) for three different Visual Studio 2022 distributions. These configuration files will work with the WinGet command line interface (i.e. `winget configure --file [path: learn_csharp_vs_community.winget]`) or can be run directly by double-clicking on the file.

Choose the configuration file that matches your Visual Studio license:

- Community: Free for individual use
- Professional: For small teams and organizations
- Enterprise: For large organizations, advanced feature

When run, the configuration file will install the following list of applications:

- Visual Studio 2022 (Community, Professional, or Enterprise)
- Required Visual Studio Workloads (ManagedDesktop, Universal)

The `configuration.winget` file will also enable [Developer Mode](https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging) on your device.

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Create a simple C# console app in Visual Studio](https://learn.microsoft.com/visualstudio/get-started/csharp/tutorial-console) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
