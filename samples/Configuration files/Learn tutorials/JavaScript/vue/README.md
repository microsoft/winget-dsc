# Install Vue.js development environment

This folder contains [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/) (WinGet) [Configuration Files](https://learn.microsoft.com/windows/package-manager/configuration/) for setting up a Vue.js development environment on Windows.

When run, the configuration file will install the following:

- Node.js LTS (provides npm)
- Visual Studio Code (recommended editor)
- Vue extension pack for VS Code
- Vue CLI (installed globally via npm)

If anything is already installed, the configuration file will skip that item.

This configuration file is based on the [Vue.js on Windows](https://learn.microsoft.com/windows/dev-environment/javascript/vue-overview) Microsoft Learn tutorial.

## Issues with Configuration file

If you experience an issue with running the provided WinGet Configuration file, you can submit a [new issue report](https://github.com/microsoft/winget-dsc/issues/new/choose), or [search existing issues](https://github.com/microsoft/winget-dsc/issues) for a preexisting issue filed by another user.
