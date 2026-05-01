# GitHub Projects

## Fork, Clone, Configure, F5

WinGet configuration files enable a powerful onboarding pattern for open source projects: **Fork → Clone → Configure → F5**. Instead of following lengthy setup guides, new contributors can get a fully configured development environment with a single command:

```powershell
winget configure --file .config\configuration.winget
```

This approach benefits open source projects by:

- **Lowering the barrier to entry** — New contributors can go from zero to building and running the project in minutes, not hours. No more hunting for the right SDK version, missing dependencies, or misconfigured environment variables.
- **Reducing onboarding friction** — Maintainers spend less time troubleshooting contributor setup issues and more time reviewing code. The configuration file *is* the setup documentation.
- **Ensuring consistency** — Every contributor starts with the same tools, versions, and settings, eliminating "works on my machine" problems before they happen.
- **Making contributions more accessible** — Developers who might otherwise be discouraged by a complex setup process can contribute to projects they care about.

By placing a `configuration.winget` file in the `.config` directory at the root of your repository, you make your project instantly approachable to any developer on Windows. The [convention for the configuration file](https://learn.microsoft.com/windows/package-manager/configuration/create#file-naming-convention) is to name it `configuration.winget` and place it in a `.config` directory in the root of the project.

## Projects

Below are known GitHub projects that use a WinGet configuration file that one can use to set up their environment for building the project. The projects are listed in alphabetical order by their GitHub repository identifier. The list is not exhaustive and is meant to be a starting point for finding projects that use a WinGet configuration file. If you know of any other projects that use a WinGet configuration file, feel free to add them to the list.

- [dev-fYnn/Winget-Repo](https://github.com/dev-fYnn/Winget-Repo/blob/master/.config/Winget-Repo_Dev.winget)
- [dotnet/eShop](https://github.com/dotnet/eShop/blob/main/.config/configuration.vsCode.winget)
- [JanDeDobbeleer/oh-my-posh](https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/.config/configuration.winget)
- [LibreOffice/core](https://github.com/LibreOffice/core/blob/master/.config/configuration.winget)
- [microsoft/PowerToys](https://github.com/microsoft/PowerToys/blob/main/.config/configuration.winget)
- [microsoft/terminal](https://github.com/microsoft/terminal/blob/main/.config/configuration.winget)
- [microsoft/vscode](https://github.com/microsoft/vscode/blob/main/.config/configuration.winget)
- [microsoft/winget-cli](https://github.com/microsoft/winget-cli/blob/master/.config/configuration.winget)
- [microsoft/winget-create](https://github.com/microsoft/winget-create/blob/main/.config/configuration.winget)
- [microsoft/winget-dsc](https://github.com/microsoft/winget-dsc/blob/main/.config/configuration.winget)
- [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs/blob/master/.config/YamlCreate.winget)
- [microsoft/winget-studio](https://github.com/microsoft/winget-studio/blob/main/.config/configuration.winget)
- [posit-dev/positron](https://github.com/posit-dev/positron/blob/main/.config/configuration.winget)
- [ryanlua/dotfiles](https://github.com/ryanlua/dotfiles/blob/main/.config/configuration.winget)
- [victorfrye/dotfiles](https://github.com/victorfrye/dotfiles/blob/main/.config/configuration.winget)
