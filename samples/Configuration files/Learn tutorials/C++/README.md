# Install C and C++ support in Visual Studio

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) ([_learn_cpp.winget_](./learn_cpp.winget)) that will work with the WinGet command line interface (`winget configure --file [path: learn_cpp.winget]`) or can be run directly by double-clicking on the file.

When run, the [learn_cpp.winget](./learn_cpp.winget) file will install the following list of applications:

- Microsoft Visual Studio Community 2022
- Required Visual Studio Workloads (NativeDesktop) along with the recommended components for C++ development

The `configuration.winget` file will also enable [Developer Mode](https://learn.microsoft.com/windows/apps/get-started/developer-mode-features-and-debugging) on your device.

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Install C and C++ support in Visual Studio](https://learn.microsoft.com/cpp/build/vscpp-step-0-installation)  Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
