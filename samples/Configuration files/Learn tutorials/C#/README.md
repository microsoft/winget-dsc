# Create a simple C# console app in Visual Studio

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) (_configuration.winget_) that will work with the WinGet command line interface (`winget configure --file [path: configuration.winget]`) or can be run directly by double-clicking on the file.

When run, the [learn_csharp.winget](./learn_csharp.winget) file will install the following list of applications:

- Microsoft Visual Studio Community 2022
- Required Visual Studio Workloads (ManagedDesktop, Universal)

The `configuration.winget` file will also enable [Developer Mode](https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging) on your device.

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Create a simple C# console app in Visual Studio](https://learn.microsoft.com/visualstudio/get-started/csharp/tutorial-console) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
