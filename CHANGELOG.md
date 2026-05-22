## 0.3.50

- Zpřehledněn výběr výchozího hlasu ve Windows.
- Opraven vzhled radio tlačítek v tmavém i světlém režimu.
- Zmenšeny mezery mezi volbami hlasů v prvotním nastavení.

## 0.3.49

- Windows installer finish page now offers to launch Dosty Speak instead of reboot options.
- Windows installer suppresses NSIS reboot prompts because the app installation itself does not require a PC restart.
- Windows installer version metadata is now read from the central VERSION file.

# 0.3.45

- Improved Windows terminal builder menu and step output.
- Windows Android builder can now install Android command-line tools, SDK platform, build-tools and NDK automatically where possible.
- Added clearer Android dependency checks from the main Windows builder.
- Added Android Qt main library metadata at application and activity level to avoid the QtLoader "main library name is null or empty" crash.

## 0.3.44

- Windows: Edge online voice now uses a private embeddable Python runtime inside the app data directory instead of the normal Python installer.
- Windows: Edge TTS can run through `python.exe -m edge_tts`, so missing `edge-tts.exe` no longer breaks speech.
- Windows: MP3 playback for Google/Edge online voices waits correctly for Windows Media Player COM to actually start, with a MediaPlayer fallback.
- GUI: online voice install path is more robust and does not depend on system-wide Python.


## 0.3.43

- Fixed Windows builder false failures caused by pacman warnings written to stderr.
- Replaced broken generated MSYS2 build script lines in scripts/build-windows-powershell.ps1.
- Windows build now cleanly configures CMake, builds, deploys, and then creates installer/portable outputs when selected.


## 0.3.41

- Fixed Windows PowerShell 5.1 parser error in scripts/build-terminal-windows.ps1 on Windows 10 LTSC 2019.
- Rewrote the Windows terminal builder as ASCII with CRLF line endings so it does not break on older Windows PowerShell encoding rules.
- Kept the menu keyboard controls: Up/Down move, Space toggle, Enter build, A all/none, Q quit.

# Changelog

## 0.3.40

- Fixed Android startup metadata placement so Qt can find the main native library.
- Added a full Windows 10 LTSC friendly terminal builder entrypoint.
- Added Android APK build support from Windows PowerShell.
- Added a one-click Windows launcher BAT that bypasses PowerShell execution policy only for this run.

## 0.3.39

- Fixed Android startup crash caused by missing Qt `android.app.lib_name` metadata.
- Forced a clean Android build directory before each APK build to avoid stale manifests and package ids.
- Android install helper now uninstalls both `cz.dosty.speak` and stale `org.qtproject.example.dosty_speak_mobile` before installing.
- Android crash log helper now launches by explicit activity and filters QtLoader/main-library errors.

## 0.3.38

- Reworked the macOS terminal builder UI into grouped, scrollable sections.
- Added visible builder option for Qt iOS kit install/check.
- Added builder presets: Desktop release, Android debug, iPhone prep and useful all.
- Fixed overflowing option list when many platform actions are available.
- Added mouse click support against the scrollable option list.

## 0.3.37

- Added `scripts/install-qt-ios-kit-macos.sh` to check for Qt iOS kit and open/drive Qt Maintenance Tool where possible.
- Updated `scripts/prepare-ios-iphone.sh` to automatically run the Qt iOS kit checker before generating the Xcode project.
- Added `scripts/open-ios-xcode-project.sh`.
- Added terminal builder hook for Qt iOS kit install/check where supported.

## 0.3.36

- Added Android crash log capture: `scripts/capture-android-crash-log.sh`.
- Added Android install helper: `scripts/install-android-apk.sh`.
- Added iPhone preparation helper: `scripts/prepare-ios-iphone.sh`.
- Added terminal builder hooks for Android install, Android crash logging and iPhone preparation where supported.

## 0.3.35

- Fixed macOS desktop installer freezing by removing GUI execution during version verification.
- Installer no longer runs `dosty-speak --version`, because the app can open as GUI and block the builder.
- Added explicit install messages and binary existence checks.
- Added timeout around `macdeployqt` so deployment cannot freeze the build forever.
- Added `scripts/reinstall-macos-desktop-clean.sh` for clean desktop reinstall.

## 0.3.34

- Rebuilt mobile QML to use only core Qt Quick items, avoiding Qt Quick Controls runtime imports on Android.
- Removed QuickControls2 dependency from the mobile target to reduce Android startup failures.
- Removed Basic style dependency from mobile startup.
- Updated Android manifest with `extractNativeLibs` and hardware acceleration.
- Added `scripts/android-logcat-dosty.sh` for focused Android crash logs.
- Clarified that users must install the signed APK from `dist/android`, not the unsigned Gradle APK.

## 0.3.33

- Fixed terminal builder appearing frozen after opening the mobile preview.
- `run-mobile-preview-macos.sh` now launches the mobile preview in the background by default.
- Added `DOSTY_WAIT_MOBILE_PREVIEW=1` for blocking/debug mobile preview runs.
- Added missing `Create macOS desktop ZIP/DMG in dist` option to the macOS builder UI.
- Added `scripts/verify-macos-dist.sh`.
- Clarified that macdeployqt issues are deployment/package warnings after successful C++ compile.

## 0.3.32

- macOS desktop build now always creates release ZIP and DMG files in `dist`.
- macOS desktop build now prefers the official Qt macOS kit over Homebrew Qt when available.
- Reduced noisy `macdeployqt` output and wrote deployment details to `build-macos/macdeployqt.log`.
- Reworked the mobile QML preview into a cleaner touch-first layout.
- Mobile quick buttons, phrase cards and preset buttons now immediately speak on tap.

## 0.3.31

- Added macOS desktop release packaging into `dist` through the terminal builder.
- New builder option: `Create macOS desktop release package in dist`.
- New script: `scripts/package-macos-desktop.sh`, creating ZIP and DMG release files.
- Mobile quick buttons, phrase cards and preset cards now call the speak path immediately on tap.
- Clarified macdeployqt dependency-copy messages as packaging warnings, not compile errors.
- Added `scripts/diagnose-macos-desktop-release.sh`.

## 0.3.30

- Fixed mobile preview and Android compile error: duplicate `MobileBridge bridge` declaration in `main_mobile.cpp`.
- `main_mobile.cpp` now contains exactly one bridge object and exactly one QML context registration.
- Mobile preview and Android build directories are cleaned before building to avoid stale generated files.
- macOS builder now skips running/packaging mobile preview if the mobile preview build failed.
- Updated mobile bridge diagnostics to catch duplicate bridge declarations.

## 0.3.29

- Fixed macOS desktop build by repairing the root `CMakeLists.txt` project block.
- Restored the full project metadata while still reading the version from the central `VERSION` file.
- Added `scripts/diagnose-desktop-cmake.sh` for quick desktop CMake diagnostics.
- Kept mobile CMake version wiring clean.

## 0.3.28

- Fixed mobile preview crash/console errors: `ReferenceError: bridge is not defined`.
- `main_mobile.cpp` now exposes `MobileBridge` to QML as the `bridge` context property.
- Ensured mobile CMake includes `MobileBridge.cpp` and `MobileBridge.h`.
- Added `scripts/diagnose-mobile-bridge.sh`.

## 0.3.27

- Made platform terminal builders the main supported build entry point.
- Added a `Run mobile preview after build` option to the macOS builder.
- Added `scripts/start-builder.sh` as a simple launcher for macOS/Linux.
- Ensured Linux and Windows terminal builder entry points exist.
- Updated README to tell users to compile through the builder menus instead of manual script calls.

## 0.3.26

- Fixed macOS desktop build after central VERSION migration by removing fragile grep-based version detection.
- Fixed mobile QML button calls by using `bridge.speakWithSettings(...)`.
- Added native macOS preview playback through `/usr/bin/say`.
- Saved phrases and presets now play on tap instead of only copying text into the input field.
- Reworked the mobile layout to avoid cropped controls and oversized text in the macOS preview.
- Forced Qt Quick Controls Basic style for the mobile app for consistent custom controls.

## 0.3.25

- Replaced the shell redraw build overlay with a Python/curses live log viewer.
- Fixed aggressive terminal flickering during macOS builder steps.
- Kept interactive/password steps outside the animated viewer.
- Added scrollable live log view with Up/Down and End.
- Progress bars still estimate phase progress, but the screen is now updated in-place.

## 0.3.24

- Fixed iOS builder stopping at signing by generating the Xcode project when APPLE_DEVELOPMENT_TEAM is not set.
- Removed sudo/xcode-select from animated build overlay so password prompts are not hidden.
- Added scripts/use-full-xcode-macos.sh for explicit interactive Xcode selection.
- macOS builder now runs iOS step interactively.
- Reduced build overlay flicker by lowering refresh rate and avoiding full clear where possible.

## 0.3.23

- Reworked macOS builder progress from an indeterminate spinner to estimated percentage bars.
- Added separate overall progress and current-step progress.
- Increased live console refresh rate.
- Redesigned the build screen as a cleaner overlay with version, step, log path and live console.
- Progress is now inferred from known build phases in the log.

## 0.3.22

- Fixed iOS builder error where CMake reported `iphoneos is not an iOS SDK`.
- iOS builder now switches xcode-select to full Xcode when possible.
- iOS builder now uses the real iPhoneOS SDK path from xcrun instead of relying on the symbolic `iphoneos` name.
- Added scripts/diagnose-ios-build-env.sh for Xcode/SDK/Qt iOS kit diagnostics.
- Kept VERSION as the single source of truth.

## 0.3.21

- Fixed CMake version wiring after moving version into the central VERSION file.
- Cleaned root and mobile project() declarations so CMake can configure reliably.
- Improved macOS terminal builder command logging with proper quoting.
- macOS builder now shows the last 80 log lines directly when a build step fails.
- Added scripts/diagnose-build-config.sh for quick CMake/version diagnostics.

## 0.3.20

- Replaced the macOS terminal builder menu with a Python/curses UI.
- Fixed broken macOS builder layout caused by long wrapped ANSI lines.
- Fixed arrow navigation by using curses key handling instead of manual escape parsing.
- Added mouse click support through curses where supported by the terminal.
- Kept VERSION as the single source of truth for app/build/log versioning.

## 0.3.19

- Added a single VERSION file used by CMake and build scripts.
- macOS builder now shows the current app version directly in the UI.
- macOS builder now uses raw terminal input for arrow keys.
- Added j/k navigation fallback for terminals that do not send normal arrow sequences.
- Mouse support is now opt-in with `m` to avoid terminal compatibility issues.
- Android and mobile preview artifact names now include the app version.

## 0.3.18

- Renamed generated archive/versioning to follow the app version instead of internal package counter.
- Fixed macOS terminal builder arrow-key handling for both ESC [ A/B and ESC O A/B sequences.
- Prevented broken arrow escape fragments from triggering the `a` toggle-all shortcut.
- Added number-key toggles in the macOS builder.
- Added basic mouse click support in the macOS terminal builder where supported.
- Improved macOS builder visual styling and log naming with app version.

## 0.3.17

- Added arrow-key terminal UI for macOS builder.
- Added progress/log split screen during non-interactive build steps.
- macOS builder now writes timestamped logs and latest-log shortcut.
- Added graphical terminal builder for Linux with logs and live build tail.
- Reworked Windows terminal builder to support arrow keys, toggles and build logs.
- Documented terminal builder controls and log locations.

## 0.3.16

- Reworked mobile QML layout to use Basic style and avoid native customization warnings.
- Fixed mobile preview buttons by wiring Speak/Save/Stop to the bridge.
- macOS mobile preview now uses `/usr/bin/say` for real speech output.
- Android build now signs the generated APK with a local debug keystore.
- Installable Android test APK is copied to `dist/android/DostySpeak-Mobile-arm64-v8a-debug-signed.apk`.

## 0.3.15

- Fixed mobile preview startup by embedding QML with qt_add_resources.
- Added bundle/resource fallback loading for mobile/qml/main.qml.
- Mobile preview build now cleans the build folder to avoid stale resource state.
- Removed empty Android build.gradle that prevented Qt from generating assembleRelease.
- Added Android styles.xml for the manifest theme.
- Android builder now installs/uses Android 36 platform/build tools where Qt 6.11 expects them.

## 0.3.14

- Fixed Android mobile target by removing the unnecessary Qt6::CorePrivate link.
- Android bridge now uses public Qt headers only.
- Mobile CMake now finalizes the executable explicitly for Qt Android.
- macOS mobile preview scripts now prefer official Qt macOS kit from ~/Qt over Homebrew Qt.
- Added mobile preview diagnostic script for Qt/QML startup failures.
- Android builder now prefers known stable NDK versions when multiple NDKs are installed.

## 0.3.13

- Android build now uses Qt's Android toolchain instead of the raw NDK toolchain.
- Android build passes Qt6_DIR explicitly to avoid Qt6Config.cmake lookup failures.
- Android build detects matching Qt host kit from the official Qt installer.
- iOS build now uses Qt's iOS toolchain and Qt6_DIR explicitly.
- macOS terminal builder delegates Android/iOS retries to robust build scripts.
- Mobile preview packaging now hides known Homebrew macdeployqt optional-module noise and creates a ZIP artifact.

## 0.3.12

- Android/iOS builders now validate Qt mobile kit folders before running CMake.
- macOS terminal builder no longer proceeds to Android/iOS CMake when Qt6Config.cmake is missing.
- Manual pause instructions now explicitly explain that Android SDK/NDK is not enough without Qt Android kit.
- Environment hint script only prints valid Qt Android/iOS kit paths.

## 0.3.11

- macOS terminal builder no longer skips Android/iOS when tools are missing.
- When a manual step is needed, the builder pauses, prints detailed instructions, and re-checks after Enter.
- Android/iOS direct build scripts now print manual step instructions before exiting when required kits are missing.

## 0.3.10

- macOS terminal builder now skips Android/iOS builds gracefully when SDKs or Qt mobile kits are missing.
- macOS dependency installer now attempts to install Android command-line tools and bootstrap Android SDK/NDK when possible.
- Android/iOS missing-kit messages are clearer.
- Mobile preview packaging script now explains that Homebrew Qt packaging is optional/noisy and recommends direct run for development.

## 0.3.9

- Fixed macOS terminal builder on the system Bash 3.2 by removing associative arrays.
- Made Linux terminal builder use the same portable array style.

## 0.3.8

- Added checkbox-style terminal builders for macOS, Linux and Windows.
- macOS terminal builder can choose desktop Mac, mobile preview, Android APK, iOS project, dependencies and release packaging.
- Linux terminal builder can choose dependencies, desktop builds, portable/DEB/RPM and mobile preview.
- Windows terminal builder can choose amd64, x86 legacy, installer, portable and mobile preview.
- macOS mobile preview now prefers direct run with Qt/QML paths instead of relying on `open` with Homebrew Qt.
- Added mobile preview package script for optional macdeployqt bundling.

## 0.3.7

- Improved mobile dependency script for macOS.
- Added dependency detection for Xcode, Android SDK/NDK, Qt Android kit and Qt iOS kit.
- Mobile preview build now runs macdeployqt with QML deployment and ad-hoc signing.
- Added `run-mobile-preview-macos.sh` for direct debugging when the preview app closes immediately.
- Android/iOS build scripts now auto-detect common SDK/Qt kit paths where possible.
- README and docs/MOBILE.md now contain direct Android/iOS build steps.

## 0.3.6

- Added direct README instructions for Android and iOS compilation.
- Added Android native TextToSpeech Java helper and JNI bridge wiring.
- Added iOS AVSpeechSynthesizer Objective-C++ bridge.
- Expanded mobile QML UI with language selector, speed slider and autocomplete chips.
- Updated mobile CMake for Android/iOS platform-specific native speech files.

## 0.3.5

- Added first Android/iOS mobile scaffold using Qt Quick/QML.
- Added touch-first mobile UI with large input, large action buttons, phrase cards and bottom navigation.
- Added mobile C++ bridge placeholder for Android TextToSpeech and iOS AVSpeechSynthesizer.
- Added mobile build scripts for macOS preview, Android APK and iOS/Xcode.
- Added `docs/MOBILE.md`.

## 0.3.4

- Replaced the inline autocomplete badge with a real suggestion list below the input field.
- Made autocomplete suggestions visible in the normal layout instead of relying on a floating popup on macOS.
- Improved combo-box dropdown styling again and widened the drop-down area.
- Tightened the speech-engine installation dialog layout to reduce empty space.

## 0.3.3

- macOS installer now prints source/installed version.
- macOS installer closes a running Dosty Speak instance before replacing the app bundle so `open` does not reuse an old running copy.
- Added `scripts/reset-macos-settings.sh` to clear macOS settings/data and show first-run wizard again.

## 0.3.2

- Reworked autocomplete into a popup-style suggestion list below the input field.
- Kept alternative suggestions subtle below the input.
- Improved combo-box dropdown styling so the dropdown affordance is visible again.
- Adjusted speech-engine setup layout so descriptions sit at the top and the dialog feels less empty.

## 0.3.1

- Restored visible dropdown arrows for combo boxes.
- Reworked autocomplete display so the main suggested completion is shown next to the input field and alternatives are shown below.
- Added app logo to the first setup screen.
- Reworked speech engine descriptions with separate pros, cons and platform compatibility details.

## 0.3.0

- Bumped version to 0.3.0.
- Fixed Tab autocomplete cycling after the first completion.
- Simplified Voice menu to Configure voice and Install/download voices.
- Reworked Configure voice dialog with synthesizer selection, concrete voice selection, engine-specific settings and preset saving.
- Reworked Install/download voices dialog for synthesizer installation and Piper voice downloads.
- Removed appearance/dark-mode settings from the Voice workflow.

## 0.2.68

- Fixed macOS/Linux/Windows compile error from an undeclared `savePresetButton` in the settings dialog.
- Removed accidental voice preset button from the phrase edit dialog.
- Improved voice dialog preset saving so it applies the selected voice before saving the preset.

## 0.2.67

- Fixed autocomplete Tab cycling so programmatic completion does not reset the suggestion state.
- Made autocomplete preview more visible and highlighted the first suggestion.
- Added voice presets saved in settings.
- Added a voice preset selector in the main window next to volume.
- Reworked the Voice dialog around choosing a voice and saving it as a preset.
- Moved speech engine installation/download management into the separate install speech engines window.

## 0.2.66

- First-run setup now requires at least one Piper voice when Piper is selected for installation.
- Added autocomplete preview under the input field.
- Repeated Tab now cycles through the next best autocomplete suggestions.
- Added a small built-in starter dictionary for autocomplete before the user has much phrase history.

## 0.2.65

- Added keyboard-first typing mode: focus stays in the text field by default.
- Tab now autocompletes the current word using locally saved phrases and usage counts.
- Up/Down now browse saved phrases while keeping typing focus in the input field.
- Esc unlocks direct phrase-list selection.

## 0.2.64

- Split first-run wizard into three steps: language/theme, engine installation, default voice selection.
- Step 3 now shows only installed or available voices.
- Improved QComboBox styling on Windows/macOS with rounded dropdown edge.
- Fixed macOS system theme detection using AppleInterfaceStyle.
- Improved Edge TTS Czech diacritics by passing text through a UTF-8 file instead of command-line text argument.

## 0.2.63

- Reworked first-run engine picker with a left engine list, install checkboxes, description/compatibility card and right-side default voice radio selection.
- Added plus/minus style compatibility/pros/cons descriptions for speech engines.
- Improved macOS eSpeak NG handling by checking Homebrew paths and opening Homebrew installer when missing.
- Fixed eSpeak NG runtime lookup on macOS app launches from Finder by using common Homebrew binary paths.

## 0.2.62

- Reworked first-run wizard into setup/install step and default voice selection step.
- Fixed language selection so Czech starter phrases are created when Czech is selected in the wizard.
- Added more basic starter phrases such as Yes/No/Please/Thank you.
- Added speech engine descriptions and compatibility notes in the wizard.
- Added multi-select Piper voice downloads in default voice wizard.
- Replaced duplicated Voice menu install actions with a single speech engine installation window.

## 0.2.61

- Added `Voice -> Install Edge TTS` with private app-managed environment.
- Windows Edge TTS installer downloads Python locally when needed, without winget.
- Added `Voice -> Install eSpeak NG` with platform-specific best-effort installation.
- Added install buttons for Edge TTS and eSpeak NG inside the voice dialog.
- Added `docs/DEPENDENCIES.md`.

## 0.2.60

- Added Microsoft Edge online voice engine through the `edge-tts` command line tool.
- Added Edge voice choices for Czech, English, Slovak, German, Polish and French.
- Added Edge TTS command setting.
- Added `docs/EDGE_TTS.md`.

## 0.2.59

- Renamed Online Google voice to a normal selectable engine instead of experimental wording.
- Added Online Google voice directly to the first-run wizard.
- Added eSpeak NG as an additional explicit speech engine.
- Hid Microsoft VC++ Runtime menu action on macOS/Linux.
- Added `docs/SPEECH_ENGINES.md`.

## 0.2.58

- Added experimental online Google Translate TTS engine while keeping native and Piper engines.
- Added online language choices: Czech, English, Slovak, German, Polish and French.
- Added MP3 playback path for online voice output on Windows/macOS/Linux.
- Added `docs/ONLINE_VOICES.md`.

## 0.2.57

- Added app menu action `Voice -> Install Microsoft VC++ Runtime` for Windows Piper/LTSC setups.
- Uses ShellExecute elevation to run the official Microsoft VC++ Redistributable installer.
- Speaker now avoids launching Piper when VCRUNTIME140/MSVCP140 are missing, preventing Windows DLL error popups.
- Windows installer now includes an optional Microsoft Visual C++ Runtime component for Piper.

## 0.2.56

- Windows Piper installer now verifies the standalone Piper runtime after extraction.
- If Piper fails to start due to missing Visual C++ runtime DLLs, Dosty Speak tries to download and run Microsoft Visual C++ Redistributable x64.
- Added clearer LTSC documentation for missing `VCRUNTIME140.dll` and `MSVCP140.dll` errors.

## 0.2.55

- Added `scripts/repair-msys2-keyring.ps1` for MSYS2 PGP signature / unknown trust / corrupted database errors.
- Windows terminal builder can offer MSYS2 keyring repair before build.
- Windows PowerShell builder now tries MSYS2 repair after failed initial update.
- x86 legacy build skips pacman installation when MINGW32 g++ is already available.
- Fixed UTF-8 setup typo in Windows terminal builder.

## 0.2.54

- Changed Windows Piper installation to use the official standalone Piper Windows runtime instead of embeddable Python/pip.
- This improves compatibility with Windows 10 2019 LTSC where winget/Python installation may be unavailable or unreliable.
- Added `docs/WINDOWS_PIPER_LTSC.md`.

## 0.2.53

- Rewrote README to be shorter and focused on current build scripts instead of version-by-version details.
- Added direct Windows build requirements with MSYS2 and NSIS download links.
- Documented that Windows build scripts do not rely on winget, useful for Windows 10 2019 LTSC.
- Added `docs/WINDOWS_BUILD.md`.

## 0.2.52

- Fixed NSIS installer generation by adding `un.CloseRunningDostySpeak` and using it from uninstall sections.
- Fixed optional uninstall-only user-data section naming.

## 0.2.51

- Fixed Windows CMake resource/icon handling by replacing generator-expression `.rc` source with a configured RC file.
- Added `scripts/clean-windows-build.ps1` for clearing stale Windows build caches.
- Windows build script now removes the old build folder before configuring.

## 0.2.49

- Fixed macOS resource placement: resources now copy to `Contents/Resources/resources` instead of `Contents/MacOS/resources`.
- macOS installer now removes old broken resources, deploys Qt, copies resources, clears xattrs and ad-hoc signs the final bundle.
- Added `scripts/debug-macos-run.sh` helper for capturing first-run crash output.

## 0.2.48

- Fixed CMake install rule for macOS MACOSX_BUNDLE target by adding `BUNDLE DESTINATION`.
- Reworked `scripts/install-macos.sh` to copy the generated `.app` bundle.
- Added `scripts/build-macos-release-terminal.sh` for macOS tar.gz/DMG release builds.

## 0.2.47

- Linux release builder now offers to install missing build dependencies automatically.
- Added `scripts/install-linux-build-deps.sh`.
- Fixed Linux builder project version detection for package file names.

## 0.2.46

- Windows installer now closes running Dosty Speak processes before reinstall/upgrade.
- Installer enables overwrite mode and schedules locked files for reboot replacement/removal.
- Fixes reinstall failures on locked Qt runtime DLLs such as Qt6Core.dll.

## 0.2.45

- Replaced logo assets with transparent-background no-text icon.
- Regenerated Windows ICO, macOS ICNS and Linux PNG icon assets.
- Added interactive Linux release builder with amd64/i386 and tar.gz/DEB/RPM options.
- Added CPack DEB/RPM metadata.

## 0.2.44

- About dialog now shows the Dosty Speak icon/photo.
- Added GitHub README logo and social preview image under `.github/assets`.
- Unified folder and phrase section headings by hiding the QTreeWidget header and using QLabel headings.

## 0.2.43

- Added UTF-8 console setup to Windows build/deploy scripts.
- Changed terminal release builder prompts/log framing to mostly ASCII to avoid mojibake in classic Windows PowerShell.

## 0.2.42

- Added Dosty Speak app icon assets for Windows/Linux/macOS.
- Added Windows RC icon and Linux desktop icon installation.
- Set NSIS installer icon.
- Unified folder/phrase section title styling.

## 0.2.41

- Removed visible Piper speed warning from main GUI.
- Added folder label and polished shortcuts dialog.
- Sorted voice catalog by language/name and added more voices.
- Cleaned up terminal release builder text and fixed duplicate installer param block.

## 0.2.40

- Added interactive terminal release builder `scripts/build-windows-release-terminal.ps1`.
- Updated Windows GUI release builder note to reflect amd64 Qt + x86 legacy Win32 reality.

## 0.2.39

- Added Tab/Enter keyboard behavior to 32-bit Win32 legacy frontend.
- Added visible volume and speed sliders to the main Qt GUI.
- Added low/faster Piper voice entries to catalog and clarified that generation speed depends on model size.

## 0.2.38

- Simplified Windows x86 path to pure Win32 legacy frontend only.
- Removed Qt/FLTK probing from x86 release flow.
- Added static GCC linking for x86 legacy build to avoid libgcc/libstdc++ DLL requirements.
- Removed unused `legacy-fltk` prototype from package.

## 0.2.37

- Added pure Win32 legacy x86 fallback that builds with only `mingw-w64-i686-gcc`.
- x86 release can now produce `DostySpeak-Legacy-Win32-Portable-x86.zip` even when Qt/FLTK x86 are unavailable.
- Fixed main CMake WIN32 usage after 0.2.36 regression.

## 0.2.36

- Windows app now builds as GUI subsystem app using `WIN32` in CMake.
- PowerShell child processes are started with `CREATE_NO_WINDOW` to avoid visible console windows.

## 0.2.35

- Fixed Windows Piper playback regression by reverting WAV playback to System.Media.SoundPlayer.
- Added Piper error logging to `piper-last-error.txt` and diagnostics.
- Added Windows x86 toolchain notes.

## 0.2.34

- Windows x86 release path now falls back to the lightweight FLTK legacy GUI if Qt x86 is unavailable.
- Added x86 legacy deployment output `DostySpeak-Legacy-Portable-x86.zip`.

## 0.2.33

- Added experimental `legacy-fltk/` lightweight GUI for older hardware and future 32-bit targets.
- Added playback volume setting.
- Added Piper quality/speed preset setting for weak CPUs.

# Changelog

## 0.2.32

- Fixed NSIS installer license page encoding by adding ASCII-safe `packaging/windows/LICENSE-installer.txt`.
- Fixed x86 generated MSYS2 scripts by adding `/usr/bin` to PATH before `pacman`/`grep` checks.
- Added `docs/GUI_TOOLKIT_OPTIONS.md` with Qt alternatives for 32-bit Windows.

## 0.2.31

- Fixed x86/arm64 generated bash scripts by passing project path as argv[1] instead of relying on dirname or embedded cd paths.

## 0.2.30

- Fixed Windows x86 generated shell script path quoting by using SCRIPT_DIR self-location instead of generated `cd /c/...` path.
- Applied the same self-location pattern to arm64 helper.

## 0.2.29

- Windows x86 build now tries CLANG32 first, then MINGW32 fallback.
- Added `deploy-windows-x86-powershell.ps1`.
- `build-windows-installer.ps1` now supports `-Arch x86` and can create `DostySpeak-Setup-x86.exe`.

## 0.2.28

- Fixed Windows x86 build script path handling by using SCRIPT_DIR.
- x86 packaging now deploys with MINGW32 windeployqt when available and copies MINGW32 DLLs.
- x86 can produce portable ZIP and NSIS setup EXE.
- Installer builder now supports `-Arch amd64` and `-Arch x86`.

## 0.2.27

- Fixed NSIS installer license page by passing absolute LICENSE path.
- Fixed generated MSYS2 scripts by writing UTF-8 without BOM.
- Switched x86 Windows build to Qt 5 because MSYS2 does not provide mingw-w64-i686-qt6-base.
- Added arm64 host check so CLANGARM64 is only attempted on Windows ARM64.
- Clarified non-fatal Qt deployment warnings.

## 0.2.26

- Added Windows release GUI with checkboxes for architecture and artifact type.
- Added CLI release builder supporting amd64/x86/arm64 selection.
- App now detects initial system light/dark theme from OS palette.
- Appearance dropdowns apply theme immediately and keep their labels updated.

## 0.2.25

- Improved Windows Czech diacritics handling for native speech using PowerShell EncodedCommand and UTF-8 BOM text file.
- Piper now receives UTF-8 text via stdin file and UTF-8 Python environment variables.

## 0.2.24

- Improved NSIS installer: Program Files install, Desktop/Start Menu shortcuts, uninstall registration, optional user data removal on uninstall, version metadata.
- Added `build-windows-portable.ps1` for portable ZIP builds.
- `build-windows-installer.ps1` now creates both installer EXE and portable ZIP.

## 0.2.23

- Added NSIS-based Windows installer script.
- Added `build-windows-installer.ps1` to create `dist/DostySpeak-Setup-x64.exe`.
- Installer installs to Program Files, creates Desktop/Start Menu shortcuts and registers an uninstaller.

## 0.2.22

- In-app reset now clears downloaded voices, Piper runtime and bundled official Python runtime for clean testing.
- Added Windows per-user install/uninstall scripts with Desktop and Start Menu shortcuts.
- Voice settings dialog now shows only voices matching the selected synthesizer engine.

## 0.2.21

- Fixed Windows native TTS Czech diacritics by passing spoken text through a UTF-8 file instead of inline PowerShell command text.
- Renamed wording from private Python to bundled official Python runtime.

## 0.2.20

- Windows Piper installer now always uses Dosty Speak private embedded Python instead of relying on system Python.
- Avoids Microsoft Store Python alias problems.

## 0.2.19

- Windows Piper setup can now install private embedded Python into Dosty Speak app data.
- If no system Python is found, app downloads Python embeddable ZIP, bootstraps pip, and installs `piper-tts` there.

## 0.2.18

- Improved Windows Python detection for Piper installation.
- App now probes Python candidates before attempting venv creation and avoids noisy Microsoft Store alias errors.

## 0.2.17

- Removed unnecessary long-option note from first-run wizard.
- Widened first-run and voice dialogs.
- Improved Windows Piper Python detection by trying `py -3`, `python3`, `python`, and MSYS2 UCRT64 Python.

## 0.2.16

- Windows deployment now copies all UCRT64 DLLs after `windeployqt` for reliability.
- Build helper automatically runs deployment helper after successful Windows build.
- Added `run-dosty-speak.cmd` to deployed Windows folder.

## 0.2.15

- Improved Windows deployment helper.
- `deploy-windows-powershell.ps1` now runs `windeployqt` and recursively copies MSYS2/UCRT DLL dependencies using `ldd`.
- README now explains that raw `build/dosty-speak.exe` is not a deployable Windows app.

## 0.2.14

- Windows PowerShell helper now installs Ninja and uses CMake generator `Ninja`.
- Fixes missing `MinGW Makefiles`/`CMAKE_MAKE_PROGRAM` error on MSYS2 UCRT64 builds.

## 0.2.13

- Windows PowerShell helper now handles MSYS2 runtime/pacman upgrades that terminate MSYS2 processes.
- MSYS2 update is run separately; dependency install/build starts in a fresh MSYS2 process.

## 0.2.12

- Reworked Windows PowerShell helper to write `.dosty-build-msys2.sh` inside the project folder and run it directly via MSYS2 bash.
- Avoids fragile `cd /c/...` command generation.

## 0.2.11

- Fixed Windows PowerShell helper newline/path quoting issue in generated MSYS2 bash script.
- Build helper now checks exit code and verifies that `build/dosty-speak.exe` exists.

## 0.2.10

- Fixed Windows PowerShell build helper temp file path conversion.
- `Convert-ToMsysPath` now supports not-yet-existing paths and temp script path is converted after creation.

## 0.2.9

- Rewrote Windows PowerShell helper with safer quoting for Windows PowerShell 5.1.
- Fixed unterminated string parser error in `build-windows-powershell.ps1`.

## 0.2.8

- Fixed Windows PowerShell build helper so PowerShell no longer parses embedded bash commands.
- The helper now writes a temporary `.sh` script and runs it through MSYS2 bash.

## 0.2.7

- Added Windows PowerShell build helper that installs/uses MSYS2 automatically.
- Added Windows deployment helper that creates a release ZIP.
- Clarified README: `pacman` is for MSYS2 shells, not PowerShell.

## 0.2.6

- Made Piper setup robust after reset and first-run wizard.
- Reuses existing Piper runtime and already downloaded voices.
- Added fallback built-in Piper voice catalog if resources are missing.
- Piper voice selection now force-saves engine/model settings.

## 0.2.5

- Fixed reset/setup wizard Piper selection so Piper runtime, voice download and active voice settings are saved correctly.
- Voice model download now blocks during first-run setup so the chosen voice is ready immediately after setup.

## 0.2.4

- First-run wizard now includes light/dark mode selection.
- Added in-app reset: clear settings/phrases and reopen first-run wizard.
- Added reset scripts for Linux, macOS and Windows.

## 0.2.3

- First-run wizard can apply language without restarting the app.
- First-run wizard can install Piper runtime and download selected Piper voice.
- Enlarged first-run, voice and settings dialogs so long options are readable.

## 0.2.2

- macOS installer now creates a real `.app` bundle in `~/Applications`.
- Added first-run setup wizard for language and initial voice selection.

## 0.2.1

- Fixed CMake/preprocessor issue with copyright metadata.
- Copyright metadata is now stored safely in `AppInfo.cpp`.

## 0.2.0

- Added About dialog.
- Added Diagnostics dialog with build/system/path information.
- Added author/license metadata.
- Added project notices and contribution docs.
- Improved GitHub readiness.

## 0.1.0

- Initial C++/Qt Dosty Speak prototype.

## 0.3.42
- Mobile preview: removed duplicate theme switch from header because the same option belongs in Settings.
- Mobile preview: added persistent saved phrases.
- Mobile preview: added editable quick phrases in the Presets tab.
- Mobile preview: quick phrase buttons still speak immediately from the main screen.

## 0.3.61

- Synced Linux terminal builder UX with the macOS builder.
- Added Linux DEB/RPM package options directly to the Linux TUI.
- Kept versioning centralized in VERSION.
