# React Native for Android (Windows)

This folder contains a WinGet configuration file to set up a React Native development environment for Android on Windows.

File:

- `learn_android_react_native.winget` — Installs Android Studio, OpenJDK 17, Node.js LTS, Git, Windows Terminal, Visual Studio Code, and Android SDK Command-Line Tools. The configuration also updates the user's PATH and sets ANDROID_HOME via a DSC script resource. (Reference: [React Native for Android](https://learn.microsoft.com/windows/dev-environment/javascript/react-native-for-android))

How to use:

```powershell
winget configure --file .\learn_android_react_native.winget
```

What gets installed:

- Android Studio
- OpenJDK 17
- Node.js LTS
- Git
- Visual Studio Code
- Windows Terminal
- Runs a Powershell script to configure and test the user's environment PATH variables after setup

If anything is already installed the configuration will skip it.

Issues:

If you encounter problems running this configuration file, submit a new issue: [Submit a new issue](https://github.com/microsoft/winget-dsc/issues/new/choose) or search existing issues: [Search issues](https://github.com/microsoft/winget-dsc/issues)
