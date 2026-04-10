# Progressive Web Apps (PWA) and Hybrid App Development (Windows)

This folder contains WinGet configuration files for building PWAs or hybrid web apps targeting Android.

`learn_android_pwa.winget` — Installs Node.js LTS, Git, Visual Studio Code, and Windows Terminal. (Reference: [Progressive web apps for Android](https://learn.microsoft.com/en-us/windows/android/pwa))

* What gets installed:
    * Node.js LTS
    * Git
    * Visual Studio Code
    * Windows Terminal

`learn_android_emulator_setup.winget` — For setting up the Android emulator to test and run hybrid apps locally. Installs Android Studio (includes emulator and AVD manager), OpenJDK 17, and Windows Terminal to support running apps on an Android emulator. (Reference: [Test your Ionic app on a device or emulator](https://learn.microsoft.com/en-us/windows/android/pwa#test-your-ionic-app-on-a-device-or-emulator))

* What gets installed:
    * Android Studio
    * Windows Terminal
    * OpenJDK 17

How to use:

```powershell
winget configure --file .\learn_android_pwa.winget
```

If anything is already installed the configuration will skip it.

Issues:

If you encounter problems running these configuration files, submit a new issue: [Submit a new issue](https://github.com/microsoft/winget-dsc/issues/new/choose) or search existing issues: [Search issues](https://github.com/microsoft/winget-dsc/issues)
