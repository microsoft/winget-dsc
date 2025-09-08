
# Install F# with Visual Studio

This folder contains [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration Files](https://learn.microsoft.com/windows/package-manager/configuration/) for three different Visual Studio 2022 distributions. These configuration files will work with the WinGet command line interface (i.e. `winget configure --file [path: learn_fsharp_vs_community.winget]`) or can be run directly by double-clicking on the file.

Choose the configuration file that matches your Visual Studio license:

- Community: Free for individual use
- Professional: For small teams and organizations
- Enterprise: For large organizations, advanced feature

When run, the configuration file will install the following:

- Visual Studio 2022 (Community, Professional, or Enterprise)
- .NET web development and ASP.NET workloads for F#

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Install F#](https://learn.microsoft.com/en-us/dotnet/fsharp/get-started/install-fsharp) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
