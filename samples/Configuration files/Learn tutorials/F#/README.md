# Install F# with Visual Studio

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) ([_learn_fsharp.winget_](./learn_fsharp.winget)) that will work with the WinGet command line interface (`winget configure --file [path: learn_fsharp.winget]`) or can be run directly by double-clicking on the file.

When run, the [learn_fsharp.winget](./learn_fsharp.winget) file will install the following list of applications:

- Microsoft Visual Studio Community 2022
- Required Visual Studio workloads for ASP.NET and web development, which includes F# and .NET Core support for ASP.NET Core projects.

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Install F#](https://learn.microsoft.com/en-us/dotnet/fsharp/get-started/install-fsharp) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
