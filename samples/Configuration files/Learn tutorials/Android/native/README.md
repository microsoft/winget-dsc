# Native Android Development (Windows)

This folder contains WinGet configuration files to install the tools required for native Android development on Windows.

Files:

- `learn_native_android.winget` — Installs Android Studio, OpenJDK 17, and Git. (Reference: [Native Android development with Windows](https://learn.microsoft.com/en-us/windows/android/native-android))
- `learn_native_android_cpp.winget` — Installs Android Studio, OpenJDK 17, Git, and native C/C++ toolchain components: CMake and LLVM/LLDB. (Reference: [Use C or C++ for Android game development](https://learn.microsoft.com/en-us/windows/android/native-android#use-c-or-c-for-android-game-development))

How to use:

```powershell
# Example: configure the C/C++ native workflow
winget configure --file .\learn_native_android_cpp.winget
```

What gets installed (examples):

- Android Studio (includes emulator and AVD Manager)
- OpenJDK 17
- Git
- CMake
- LLVM/LLDB for debugging native C/C++ code

If anything is already installed the configuration will skip it.

Issues:

If you encounter problems running these configuration files, submit a new issue: [Submit a new issue](https://github.com/microsoft/winget-dsc/issues/new/choose) or search existing issues: [Search issues](https://github.com/microsoft/winget-dsc/issues)
