# Get started using Rust on Windows for beginners

This folder contains a [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration File](https://learn.microsoft.com/windows/package-manager/configuration/) ([_learn_rust_vscode.winget_](./learn_rust_vscode.winget)) that will work with the WinGet command line interface (`winget configure --file [path: learn_rust_vscode.winget]`) or can be run directly by double-clicking on the file.

When run, the [learn_rust_vscode.winget](./learn_rust_vscode.winget) file will install the following list of applications:

- Visual Studio Code
- CodeLLDB VS Code extension
- Rust-analyzer VS Code extension
- Rustup toolchain
- Microsoft C and C++ (MSVC) toolchain

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the Visual Studio Code workload in the [Set up your dev environment on Windows for Rust](https://learn.microsoft.com/en-us/windows/dev-environment/rust/setup#install-visual-studio-code) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
