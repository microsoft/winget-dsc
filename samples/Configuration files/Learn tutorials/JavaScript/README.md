# Understanding WinGet Configuration Files

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) (_configuration.winget_) that will work with the WinGet command line interface (`winget configure --file [path: configuration.winget]`) or can be run directly by double-clicking on the file.

When run, the [learn_nodejs.winget](./learn_nodejs.winget) file will install the following list of applications:

- Git for Windows
- Visual Studio Code
- NVM for Windows

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Install Node.js on Windows](https://learn.microsoft.com/windows/dev-environment/javascript/nodejs-on-windows) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
