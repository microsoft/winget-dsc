# Start developing Windows Apps

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) (_learn_python.winget_) that will work with the WinGet command line interface (`winget configure --file [path: learn_python.winget]`) or can be run directly by double-clicking on the file.

When run, the [learn_winappdev.winget](./learn_winappdev.winget) file will install the following list of applications:

- Microsoft Visual Studio Community 2022
- Required Visual Studio Universal workload along with the recommended components for Windows app development

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Start developing Windows apps](https://learn.microsoft.com/windows/apps/get-started/start-here) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
