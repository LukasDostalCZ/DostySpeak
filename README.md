<p align="center"><img src=".github/assets/dosty-speak-logo.png" width="128" alt="Dosty Speak logo"></p>

# Dosty Speak

**Dosty Speak** is a small cross-platform text-to-speech app for quickly speaking typed and saved phrases.

It is built in **C++17 + Qt Widgets**.

Author: **Lukáš Dostál**  
License: **MIT**  
Current version: **0.3.39**

---

## What it does

- speak typed text,
- save frequently used phrases,
- organize phrases into folders,
- use keyboard-friendly controls,
- use system voices or Piper voices where available,
- run on macOS, Windows and Linux.

---

## Supported builds

| Platform | Status |
|---|---|
| macOS | Main modern Qt app |
| Windows 64-bit | Main modern Qt app, installer EXE and portable ZIP |
| Windows 32-bit | Very limited legacy Win32 build, no Piper/Python, basic phrase speaking only |
| Linux | Main modern Qt app, portable tar.gz, DEB and RPM |

---

## Windows build

### Requirements

Install these manually first:

1. **MSYS2**  
   Download and install from:  
   https://www.msys2.org/

2. **NSIS** for the Windows installer EXE  
   Download and install from:  
   https://nsis.sourceforge.io/Download

Windows 10 2019 LTSC may not have `winget`, so the build scripts do **not** rely on it. Install MSYS2 and NSIS from the links above.

### Build

Open **Windows PowerShell** in the project folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release-terminal.ps1
```

The script lets you choose:

- Windows 64-bit main app,
- Windows 32-bit legacy app,
- installer EXE,
- portable ZIP.

Outputs are created in:

```text
dist\
```

Typical files:

```text
DostySpeak-Setup-x64.exe
DostySpeak-Portable-x64.zip
DostySpeak-Legacy-Win32-Portable-x86.zip
```

### Clean Windows build cache

If Windows build starts failing after changes, clean the build folders first:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clean-windows-build.ps1
```

Then run the release builder again.

### Windows 32-bit note

The 32-bit Windows build is a separate **legacy Win32** frontend. It is intentionally limited and uses Windows SAPI directly. It does not use Qt, Piper or Python.

---

## macOS build

### Requirements

Install Homebrew first:  
https://brew.sh/

Then run from the project folder:

```bash
chmod +x scripts/install-macos.sh
./scripts/install-macos.sh
open "$HOME/Applications/Dosty Speak.app"
```

This builds and installs:

```text
~/Applications/Dosty Speak.app
```

### macOS release package

To create a release package:

```bash
chmod +x scripts/build-macos-release-terminal.sh
./scripts/build-macos-release-terminal.sh
```

Outputs are created in:

```text
dist/
```

If the app closes immediately, run:

```bash
chmod +x scripts/debug-macos-run.sh
./scripts/debug-macos-run.sh
```

and check the terminal output.

---

## Linux build

### Quick dependency install

From the project folder:

```bash
chmod +x scripts/install-linux-build-deps.sh
./scripts/install-linux-build-deps.sh
```

### Build packages

Run the interactive Linux builder:

```bash
chmod +x scripts/build-linux-release-terminal.sh
./scripts/build-linux-release-terminal.sh
```

The script lets you choose:

- x86_64 / amd64,
- i386 / 32-bit when running inside a real 32-bit Linux environment,
- portable tar.gz,
- DEB,
- RPM.

Outputs are created in:

```text
dist/
```

Typical files:

```text
DostySpeak-Linux-x86_64.tar.gz
DostySpeak-0.2.xx-x86_64.deb
DostySpeak-0.2.xx-x86_64.rpm
```

### Linux 32-bit note

For 32-bit Linux builds, use a real 32-bit chroot, container or VM. Cross-building Qt from a normal 64-bit system is unreliable.

---

## GitHub release assets

Recommended first release assets:

```text
DostySpeak-Setup-x64.exe
DostySpeak-Portable-x64.zip
DostySpeak-Legacy-Win32-Portable-x86.zip
DostySpeak-macOS-*.tar.gz
DostySpeak-*.dmg
DostySpeak-Linux-x86_64.tar.gz
*.deb
*.rpm
```

---

## Troubleshooting

### Windows installer cannot overwrite files

Close Dosty Speak and retry. If needed:

```powershell
taskkill /F /T /IM dosty-speak.exe
```

### Windows build still fails

Clean first:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clean-windows-build.ps1
```

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release-terminal.ps1
```

### macOS app closes immediately

Run:

```bash
./scripts/debug-macos-run.sh
```

### Linux builder says `Missing tools`

Run:

```bash
./scripts/install-linux-build-deps.sh
```

---

## Changelog

Detailed version history is in:

```text
CHANGELOG.md
```


### Windows LTSC Piper note

Windows 10 2019 LTSC may not have `winget`, and Python installation can be problematic. On Windows, Dosty Speak now installs Piper from the standalone official Piper Windows runtime instead of using Python/pip.

More details:

```text
docs/WINDOWS_PIPER_LTSC.md
```


### MSYS2 keyring/database repair

If Windows build fails with MSYS2 PGP signature errors such as `unknown trust` or `invalid or corrupted database`, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\repair-msys2-keyring.ps1
```

Then run the Windows builder again.

More details:

```text
docs/MSYS2_KEYRING_REPAIR.md
```


### Windows LTSC Piper runtime note

If Piper on Windows 10 LTSC fails with missing DLLs such as:

```text
VCRUNTIME140.dll
MSVCP140.dll
```

install Microsoft Visual C++ Redistributable x64:

```text
https://aka.ms/vs/17/release/vc_redist.x64.exe
```

Dosty Speak tries to install it automatically when Piper is configured, but Windows may ask for administrator permission.

More details:

```text
docs/WINDOWS_PIPER_LTSC.md
```


### Windows Piper VC++ Runtime helper

On Windows 10 LTSC, Piper may need Microsoft Visual C++ Redistributable x64.

Inside the app, use:

```text
Voice -> Install Microsoft VC++ Runtime
```

The Windows installer also includes an optional component for the same runtime.


### Online voice engine

Dosty Speak also includes an optional online Google voice engine.

Use it in:

```text
Voice -> Select voice -> Online Google voice
```

It requires internet and is less reliable than Piper or native system voices.

Details:

```text
docs/ONLINE_VOICES.md
```


### Speech engines

Dosty Speak now includes these speech engines:

```text
Native system voice
Piper
Online Google voice
eSpeak NG
```

More details:

```text
docs/SPEECH_ENGINES.md
```


### Microsoft Edge online voice

Another optional online synthesizer is available through `edge-tts`:

```bash
python -m pip install edge-tts
```

Then select:

```text
Voice -> Select voice -> Microsoft Edge online voice
```

Details:

```text
docs/EDGE_TTS.md
```


### Optional dependency installation

Dosty Speak can help install optional engines:

```text
Voice -> Install Edge TTS
Voice -> Install eSpeak NG
```

More details:

```text
docs/DEPENDENCIES.md
```


### First-run wizard

The first-run wizard now works in two steps:

1. choose language, appearance and which speech engines to install,
2. choose the default synthesizer and voice.

When Czech is selected, starter phrases are created in Czech.


### First-run engine picker

The first-run wizard now has a nicer speech engine picker:

- engine list with install checkboxes,
- description and compatibility card,
- voice selection on the right,
- radio-style default voice choice,
- extra Piper voice downloads.

On macOS, eSpeak NG installation now tries common Homebrew paths and can open the Homebrew installer in Terminal when Homebrew is missing.


### Three-step first-run wizard

The first-run setup is now split into three clearer steps:

1. language and appearance,
2. speech engine and voice installation,
3. default voice selection from installed/available voices only.

The system theme detection on macOS now checks the real macOS appearance setting, and Edge TTS now passes text through a UTF-8 file to avoid broken Czech characters.


### Keyboard-first typing mode

The main typing field now keeps keyboard focus by default:

- `Tab` completes the current word from saved phrases,
- `Up` / `Down` browses saved phrases while keeping focus in the input,
- `Enter` speaks the current input,
- `Shift + Enter` saves the current input,
- `Esc` unlocks direct phrase-list selection.

Autocomplete is local and privacy-friendly. It learns from saved phrases and phrase usage counts.


### Autocomplete preview and cycling

Autocomplete is still fully local and privacy-friendly.

- the hint below the input shows what Tab can complete,
- repeated Tab cycles through the next best suggestions,
- suggestions come from saved phrases, usage counts and a small built-in starter word set,
- no online model is downloaded for this feature.

During first-run setup, if Piper is selected for installation, at least one Piper voice must also be selected.


### Voice presets

Voice and synthesizer settings can now be saved as presets.

- open `Voice -> Select voice`,
- choose engine and voice,
- click `Save as preset`,
- switch presets later from the main window next to the volume control.

The Voice dialog now focuses on voice selection and presets. Engine installation and voice downloads are handled from the separate `Voice -> Install speech engines` window.

Autocomplete preview is more visible, and repeated Tab cycling no longer resets after the first completion.


### macOS compile fix for voice presets

Version 0.2.68 fixes a build error caused by a misplaced preset button connection in the settings dialog.


### Version 0.3.0

This release cleans up the voice workflow:

- Voice menu has two main actions: configure voice, and install/download voices.
- Configure voice contains synthesizer, concrete voice, engine-specific settings and preset saving.
- Install/download voices contains synthesizer installation and Piper voice downloads.
- Tab autocomplete cycling was fixed so repeated Tab continues cycling suggestions.


### UI polish for voice setup and autocomplete

Version 0.3.1 improves several UI details:

- combo boxes show a visible dropdown arrow again,
- autocomplete shows the main completion next to the input field,
- alternative autocomplete suggestions are listed below,
- the first-run setup shows the app logo,
- speech engine descriptions now use clearer pros, cons and platform compatibility sections.


### Autocomplete popup polish

Version 0.3.2 changes autocomplete to a popup-style suggestion list below the input, closer to classic desktop autocomplete behavior. It also restores more usable combo-box dropdown affordances and improves the first-run speech engine layout.


### macOS install verification

The macOS installer now closes any running Dosty Speak instance before replacing the app bundle and prints the source and installed app version.

To force the first-run wizard again on macOS:

```bash
chmod +x scripts/reset-macos-settings.sh
./scripts/reset-macos-settings.sh
open "$HOME/Applications/Dosty Speak.app"
```


### Autocomplete list is now part of the main layout

Version 0.3.4 changes the autocomplete UI from an inline badge to a real suggestion list directly below the text input. This avoids macOS popup quirks and makes the behavior closer to a classic desktop autocomplete list.


## Dosty Speak Mobile

Experimental mobile scaffold is included in:

```text
mobile/
```

Build scripts:

```bash
scripts/build-mobile-preview-macos.sh
scripts/build-android-apk.sh
scripts/build-ios.sh
```

Documentation:

```text
docs/MOBILE.md
```

The first mobile target uses a Qt Quick / QML touch UI and platform-native speech bridges.


## Mobile build, Android and iOS

Mobile code lives in:

```text
mobile/
```

The mobile app uses Qt Quick/QML. The desktop Qt Widgets UI is not used on mobile.

### 1. Install/check dependencies on macOS

Run:

```bash
cd ~/Dev/dosty-speak
chmod +x scripts/install-mobile-build-deps-macos.sh
./scripts/install-mobile-build-deps-macos.sh
```

The script installs/checks what it reasonably can:

```text
Homebrew
Xcode Command Line Tools
cmake
ninja
desktop Qt for macOS preview
Android Studio
JDK 17
Android platform tools
```

The script also detects and prints paths for:

```text
Android SDK
Android NDK
Qt Android kit
Qt iOS kit
Xcode
```

Important limitation: Qt Android and Qt iOS kits are not available from Homebrew Qt. Install them with the official Qt online installer when the script says they are missing.

### 2. Build mobile preview on macOS

This tests the mobile UI as a normal macOS app:

```bash
chmod +x scripts/build-mobile-preview-macos.sh
./scripts/build-mobile-preview-macos.sh
open "build-mobile-preview-macos/dosty-speak-mobile.app"
```

If the app closes immediately, run it directly to see the log:

```bash
chmod +x scripts/run-mobile-preview-macos.sh
./scripts/run-mobile-preview-macos.sh
```

### 3. Android APK

Install through Android Studio first if missing:

```text
Android SDK
Android NDK
Android platform
Qt Android arm64 kit
```

Then run:

```bash
chmod +x scripts/print-mobile-env-hints.sh
./scripts/print-mobile-env-hints.sh
```

Copy/export the printed variables if needed, then build:

```bash
chmod +x scripts/build-android-apk.sh
./scripts/build-android-apk.sh
```

The APK is usually created under:

```text
build-android-arm64-v8a/android-build/build/outputs/apk/
```

Android speech uses native Android `TextToSpeech`:

```text
mobile/android/src/cz/dosty/speak/DostyTts.java
```

### 4. iOS build

Install first:

```text
Full Xcode
Qt iOS kit
Apple signing/team setup
```

Then run:

```bash
chmod +x scripts/print-mobile-env-hints.sh
./scripts/print-mobile-env-hints.sh

chmod +x scripts/build-ios.sh
./scripts/build-ios.sh
```

If signing fails, open the generated Xcode project and select your Team manually:

```bash
open "build-ios/DostySpeakMobile.xcodeproj"
```

iOS speech uses native `AVSpeechSynthesizer`:

```text
mobile/IosTts.mm
```

### Mobile feature status

Works in the mobile scaffold:

```text
touch UI
large text input
Speak / Save / Stop buttons
quick phrase buttons
phrase cards
language selector
speech speed slider
Android native TextToSpeech bridge
iOS native AVSpeechSynthesizer bridge
```

Still planned:

```text
persistent mobile phrase storage
full mobile preset management
mobile autocomplete from saved phrases
Piper as native embedded mobile engine
online Google/Edge mobile voices
```

Desktop Python/Piper/edge-tts cannot be copied 1:1 to iOS and Android because mobile systems do not allow the same free runtime installation and external process execution as desktop systems.



## Terminal builders

There are terminal builders with checkbox-style selection.

### macOS

```bash
cd ~/Dev/dosty-speak
chmod +x scripts/build-terminal-macos.sh
./scripts/build-terminal-macos.sh
```

The macOS builder can ask for:

```text
dependencies
macOS desktop app
mobile preview for this Mac
Android APK
iOS app / Xcode project
desktop release bundle
mobile preview package
```

### Linux

```bash
chmod +x scripts/build-terminal-linux.sh
./scripts/build-terminal-linux.sh
```

The Linux builder can ask for:

```text
dependencies
desktop amd64
desktop i386, only inside a real 32-bit environment
portable tar.gz
DEB
RPM
mobile preview
```

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```

The Windows builder can ask for:

```text
dependencies
amd64 build
x86 legacy build
installer EXE
portable ZIP
mobile preview
```

## Mobile preview note

For the macOS mobile preview, prefer this:

```bash
./scripts/build-mobile-preview-macos.sh
./scripts/run-mobile-preview-macos.sh
```

Do not rely on `open build-mobile-preview-macos/dosty-speak-mobile.app` while using Homebrew Qt. Running directly through `run-mobile-preview-macos.sh` sets the Qt/QML runtime paths and gives useful logs.



### Bash 3.2 compatible builders

macOS ships an old Bash 3.2 by default. The terminal builders avoid associative arrays so they run with the system `/bin/bash` without requiring a newer shell.


### macOS builder behavior

The macOS terminal builder now skips Android/iOS targets instead of aborting when their SDKs are missing.

Android requires all three:

```text
Android SDK
Android NDK
Qt Android kit
```

iOS requires:

```text
Full Xcode
Qt iOS kit
```

Homebrew can install helper tools, but Qt Android/iOS kits must be installed with the official Qt online installer. For mobile preview on Mac, use:

```bash
./scripts/build-mobile-preview-macos.sh
./scripts/run-mobile-preview-macos.sh
```

Packaging the mobile preview `.app` with Homebrew Qt is optional and can print many missing optional Qt module warnings.



### Manual dependency pauses

When Android or iOS is selected in the macOS terminal builder and something cannot be installed automatically, the script now pauses and gives step-by-step instructions. After you finish the manual step, return to Terminal and press Enter. The script checks again and continues when the required tools are present.

You can quit the paused builder by typing:

```text
q
```



### Qt mobile kit validation

Android and iOS builders now validate that the selected Qt mobile kit actually contains:

```text
lib/cmake/Qt6/Qt6Config.cmake
```

Android SDK and NDK alone are not enough. You also need the Qt Android kit from the Qt online installer.


### Mobile build automation

The Android builder now uses Qt's own Android CMake toolchain:

```text
<Qt Android kit>/lib/cmake/Qt6/qt.toolchain.cmake
```

It also detects the matching Qt host kit, usually:

```text
~/Qt/<version>/macos
```

This avoids the common `Could not find Qt6Config.cmake` failure caused by using only the Android NDK toolchain.



### Mobile preview diagnostics

If the macOS mobile preview builds but does not open, run:

```bash
./scripts/run-mobile-preview-macos.sh
```

For full Qt/QML diagnostics:

```bash
./scripts/diagnose-mobile-preview-macos.sh
```

The preview scripts now prefer the official Qt macOS kit from `~/Qt/<version>/macos` over Homebrew Qt when it exists.


### Mobile QML resource fix

The mobile app now embeds `qml/main.qml` explicitly through `qt_add_resources` and also copies it into the app bundle as a fallback. The macOS mobile preview script cleans the build folder before rebuilding, so stale resource state should not survive between runs.

Android packaging no longer ships an empty custom `mobile/android/build.gradle`; Qt is allowed to generate the correct Gradle project and `assembleRelease` task.


### Android signed APK

The Android build now signs the generated APK with a local debug keystore so it can be installed for testing.

Expected installable output:

```text
dist/android/DostySpeak-Mobile-arm64-v8a-debug-signed.apk
```

This is a debug-signed test package, not a Play Store release signing setup.


### Graphical terminal builders with logs

The terminal builders now support keyboard navigation and automatic logs.

macOS:

```bash
./scripts/build-terminal-macos.sh
```

Linux:

```bash
./scripts/build-terminal-linux.sh
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```

Controls:

```text
Up/Down  move selection
Space    toggle selected item
Enter    start build
a        toggle all
q        quit
```

Build logs are saved automatically:

```text
logs/macos-build-YYYYMMDD-HHMMSS.log
logs/linux-build-YYYYMMDD-HHMMSS.log
logs/windows-build-YYYYMMDD-HHMMSS.log
```

The latest log shortcuts are:

```text
logs/latest-macos-build.log
logs/latest-linux-build.log
logs/latest-windows-build.log
```

During non-interactive build steps, the terminal shows an indeterminate progress bar and a live console tail.


### macOS builder arrow and mouse controls

The macOS terminal builder supports:

```text
Up/Down  move selection
Space    toggle highlighted item
1-6      toggle item by number
Mouse    click item to select/toggle, where supported by the terminal
Enter    start build
a        toggle all
l        open logs folder
q        quit
```

The arrow key reader handles both common macOS terminal escape variants:

```text
ESC [ A / ESC [ B
ESC O A / ESC O B
```

Unknown escape fragments are ignored so arrow keys should not accidentally trigger `a` / toggle-all.


### Single source of version

The app version is stored in one file:

```text
VERSION
```

CMake reads this file for desktop and mobile builds. Build scripts also read it through:

```text
scripts/version.sh
```

This keeps package names, logs and app metadata aligned.


### macOS builder navigation fallback

If arrow keys do not work in a specific terminal, use:

```text
j  move down
k  move up
```

The builder uses raw terminal input so macOS arrow escape sequences should no longer trigger the `a` toggle-all action.


### macOS builder uses curses

The macOS terminal builder now uses a small Python/curses UI instead of hand-parsed terminal escape sequences. This is more reliable for arrow keys and prevents broken layout caused by wrapped ANSI output.

Controls:

```text
Up/Down  move
j/k      move fallback
Space    toggle
1-6      toggle by number
Mouse    click item where supported
Enter    continue
a        toggle all
l        open logs
q        quit
```


### Build config diagnostics

If a builder step fails before showing a clear compiler error, run:

```bash
./scripts/diagnose-build-config.sh
```

This checks that the central `VERSION` file is correctly wired into both desktop and mobile CMake projects.


### iOS SDK detection

If iOS build fails, run:

```bash
./scripts/diagnose-ios-build-env.sh
```

The iOS builder automatically checks that `xcode-select` points to full Xcode and uses the real iPhoneOS SDK path from:

```bash
xcrun --sdk iphoneos --show-sdk-path
```

This avoids the CMake error:

```text
iphoneos is not an iOS SDK
```


### Build overlay progress

The macOS terminal builder shows a build overlay while each non-interactive step runs.

It includes:

```text
current app version
current step / total selected steps
overall progress percent
current step progress percent
live console output
log path
```

Progress is estimated from known build phases found in the log, for example CMake configure/generate, compile, macdeployqt, Android APK creation and APK signing.


### iOS signing and password prompts

The animated build overlay must not run `sudo`, because password prompts can be hidden by the live redraw.

For iOS setup, run this manually once:

```bash
./scripts/use-full-xcode-macos.sh
```

For device builds, iOS signing also needs an Apple Development Team ID:

```bash
export APPLE_DEVELOPMENT_TEAM="YOURTEAMID"
./scripts/build-ios.sh
```

Without `APPLE_DEVELOPMENT_TEAM`, the script generates the Xcode project and stops before compiling/signing. Open the project in Xcode and select your Team in Signing & Capabilities.


### Non-flicker build viewer

The macOS terminal builder uses a Python/curses log viewer for non-interactive build steps. It updates the screen in-place instead of clearing and redrawing from shell, so it should not flash aggressively.

Interactive steps, such as dependency installation or iOS signing, are not run inside the animated viewer so password prompts stay usable.


### Mobile preview behavior

In the mobile preview, tapping a saved phrase or preset now puts it into the text field and immediately plays it.

The desktop macOS preview uses the native `/usr/bin/say` command. Android uses the native Android TextToSpeech bridge. iOS uses the native AVSpeechSynthesizer bridge.


## Build everything through the terminal builder

Use the terminal builder as the main entry point. Pick what to compile inside the menu.

macOS:

```bash
cd ~/Dev/dosty-speak
chmod +x scripts/build-terminal-macos.sh
./scripts/build-terminal-macos.sh
```

Linux:

```bash
cd ~/dosty-speak
chmod +x scripts/build-terminal-linux.sh
./scripts/build-terminal-linux.sh
```

Windows PowerShell:

```powershell
cd C:\path\to\dosty-speak
powershell -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```

There is also a small OS-detecting launcher for macOS/Linux:

```bash
./scripts/start-builder.sh
```

You should not need to run the individual build scripts manually during normal use.


### Mobile bridge diagnostics

If mobile preview says `ReferenceError: bridge is not defined`, run:

```bash
./scripts/diagnose-mobile-bridge.sh
```

The mobile app must create `MobileBridge` in `main_mobile.cpp` and expose it to QML as:

```cpp
engine.rootContext()->setContextProperty(QStringLiteral("bridge"), &bridge);
```


### Desktop CMake diagnostics

If the macOS desktop build stops immediately after Homebrew messages, check the desktop CMake file:

```bash
./scripts/diagnose-desktop-cmake.sh
```

This verifies that the root `CMakeLists.txt` parses and configures correctly.


### macOS desktop release output

The macOS desktop build installs the app to:

```bash
~/Applications/Dosty Speak.app
```

To put release files into `dist`, select this builder option too:

```text
Create macOS desktop release package in dist
```

It creates:

```text
dist/DostySpeak-macOS-<version>.zip
dist/DostySpeak-macOS-<version>.dmg
```


### macOS desktop release behavior

The macOS desktop builder now always creates release files in `dist` as part of the desktop build:

```text
dist/DostySpeak-macOS-<version>.zip
dist/DostySpeak-macOS-<version>.dmg
```

The script prefers the official Qt macOS kit from `~/Qt/<version>/macos` when available, because Homebrew Qt often causes noisy `macdeployqt` dependency-copy errors.


### Mobile preview run behavior

The builder launches the mobile preview in the background so the builder can continue.
For a blocking debug run, use:

```bash
DOSTY_WAIT_MOBILE_PREVIEW=1 ./scripts/run-mobile-preview-macos.sh
```

The runtime log is written to:

```text
/tmp/dosty-speak-mobile-preview.log
```


### Android crash diagnostics

Install only the signed APK from:

```text
dist/android/DostySpeak-Mobile-<version>-arm64-v8a-debug-signed.apk
```

Do not install `android-build-release-unsigned.apk`.

If Android still shows a fatal error, connect the phone by USB and run:

```bash
./scripts/android-logcat-dosty.sh
```

Then open the app and send the log output.


### Clean macOS desktop reinstall

If the builder appears to freeze while the desktop app opens, use:

```bash
./scripts/reinstall-macos-desktop-clean.sh
```

The installer does not launch the GUI app during verification. It only checks that the app binary exists and is executable.


### Android crash log capture

If Android shows “fatal error and cannot continue”, connect the phone by USB with USB debugging enabled and run:

```bash
./scripts/capture-android-crash-log.sh
```

It creates:

```text
logs/dosty-speak-<version>-android-crash-<date>.log
logs/dosty-speak-<version>-android-crash-<date>-filtered.log
```

Send the filtered log first.

### Install Android APK to phone

```bash
./scripts/install-android-apk.sh
```

This installs the latest signed APK from `dist/android`.

### Prepare iPhone build

```bash
./scripts/prepare-ios-iphone.sh
```

It checks Xcode and the Qt iOS kit, generates the Xcode project and opens Xcode so you can select your Team and run it on your iPhone.


### Qt iOS kit install/check

The script can check for the Qt iOS kit and try to install it through Qt Maintenance Tool:

```bash
./scripts/install-qt-ios-kit-macos.sh
```

If Qt requires login or interactive component selection, the script opens Maintenance Tool and waits.

### Prepare and open iPhone project in Xcode

```bash
./scripts/prepare-ios-iphone.sh
```

This checks Xcode, checks or installs the Qt iOS kit, generates `build-ios/DostySpeakMobile.xcodeproj` and opens it in Xcode.

For a real iPhone, Xcode still requires selecting a Team in Signing & Capabilities.


### Builder menu

The macOS terminal builder is now grouped and scrollable so the options do not overflow the terminal.

Useful presets inside the builder:

```text
1 Desktop release
2 Android debug
3 iPhone prep
4 Everything useful
```

Use ↑/↓ or j/k to move, Space to toggle, Enter to start.


### Android crash fixed in 0.3.39

If Android closed right after the splash screen with this log:

```text
QtLoader: The main library name is null or empty.
System.exit called, status: -1
```

the APK manifest was missing Qt's `android.app.lib_name` metadata. Version 0.3.39 adds that metadata and the install helper now removes the old Qt example package id before installing the fresh APK.
