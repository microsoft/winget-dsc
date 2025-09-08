# Install F# with Visual Studio Code

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) ([_learn_fsharp.winget_](./learn_fsharp_vscode.winget)) that will work with the WinGet command line interface (`winget configure --file [path: learn_fsharp_vscode.winget]`) or can be run directly by double-clicking on the file.

When run, the [learn_fsharp_vscode.winget](./learn_fsharp_vscode.winget) file will install the following list of applications:

- Git
- Microsoft .NET 9 SDK
- Microsoft Visual Studio Code
- ionide-fsharp extension for Visual Studio Code

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Install F#](https://learn.microsoft.com/en-us/dotnet/fsharp/get-started/install-fsharp) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
