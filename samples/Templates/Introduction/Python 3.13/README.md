# Understanding WinGet Configuration Files

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) (_learn_python.winget_) that will work with the WinGet command line interface (`winget configure --file [path: learn_python.winget]`) or can be run directly by double-clicking on the file.

When run, the `learn_python.winget` file will install the following list of applications:

- Python 3.13
- Visual Studio Code
- Visual Studio Code extension for Python
- Git (optional)

If anything is already installed, it will skip that item. 

## How to use the WinGet Configuration File

### File Explorer

1. Download the `learn_python.winget` file to your computer.
2. Double-click the `learn_python.winget` file.

### Command line

1. Download the `learn_python.winget` file to your computer.
2. Open your Windows Start Menu, search and launch "_Windows Terminal_".
3. Type the following: `CD <C:\Users\User\Download>`
4. Type the following: `winget configure --file .\learn_python.winget`

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
