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
