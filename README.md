<p align="center"><img src=".github/assets/dosty-speak-logo.png" width="128" alt="Dosty Speak logo"></p>

# Dosty Speak

**Dosty Speak** is a small cross-platform phrase based text-to-speech app written in **C++17 + Qt Widgets**.

Author: **Lukáš Dostál**  
License: **MIT**  
Current version: **0.2.49**

---

## Build and run — Linux

These commands assume you are already inside the project folder.

### Ubuntu / Debian — Qt 6

```bash
sudo apt update
sudo apt install -y build-essential cmake qt6-base-dev qt6-base-dev-tools python3 python3-venv espeak-ng alsa-utils

rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"

./build/dosty-speak
```

### Ubuntu / Debian — Qt 5 fallback

Use this on older or 32-bit systems where Qt 6 is not available.

```bash
sudo apt update
sudo apt install -y build-essential cmake qtbase5-dev qtbase5-dev-tools python3 python3-venv espeak-ng alsa-utils

rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"

./build/dosty-speak
```

### Install on Linux into your user account

```bash
chmod +x scripts/install-linux.sh
./scripts/install-linux.sh
```

After installation:

```bash
dosty-speak
```

If the command is not found, close and reopen the terminal or run:

```bash
export PATH="$HOME/.local/bin:$PATH"
dosty-speak
```

---

## Build and run — macOS

These commands assume you are already inside the project folder.

### 1. Install tools

Install Homebrew first if you do not have it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install Qt and CMake:

```bash
brew install cmake qt
```

### 2. Build

```bash
rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$(brew --prefix qt)"
cmake --build build -j"$(sysctl -n hw.ncpu)"
```

### 3. Run

```bash
./build/dosty-speak
```

macOS uses the built-in `say` command for native speech.

### 4. Install locally on macOS

```bash
chmod +x scripts/install-macos.sh
./scripts/install-macos.sh
```

After installation, run:

```bash
"$HOME/.local/bin/dosty-speak"
```

The installer also creates:

```text
~/Applications/Dosty Speak.app
```

### 5. Create a distributable macOS app later

For a proper `.app` or `.dmg`, use Qt deployment tools after creating an app bundle:

```bash
macdeployqt "Dosty Speak.app" -dmg
```

This part may need extra polishing depending on your Qt/CMake setup.

---

## Build and run — Windows 10/11 64-bit

There are two options.

### Option A — copy/paste from normal PowerShell

These commands assume you are already inside the project folder in **normal Windows PowerShell**.

Do **not** run `pacman` directly in PowerShell. `pacman` exists only inside MSYS2.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-powershell.ps1
```

The raw `build\dosty-speak.exe` is not enough for normal double-click use, because it needs Qt/MSYS2 DLLs.

Create a runnable Windows folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-windows-powershell.ps1
```

Run the deployed app:

```powershell
.\dist\DostySpeak-Windows-x86_64\dosty-speak.exe
```

This creates:

```text
dist\DostySpeak-Windows-x86_64.zip
```

### Option B — manual build inside MSYS2 UCRT64

Install MSYS2 from:

```text
https://www.msys2.org/
```

Open **MSYS2 UCRT64**. Then go to the project folder.

Example:

```bash
cd /c/Users/Lukli/Downloads/dosty-speak-cpp-project-v18/dosty-speak
```

Then run:

```bash
pacman -Syu
pacman -S --needed mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-qt6-base mingw-w64-ucrt-x86_64-python

rm -rf build
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -j

./build/dosty-speak.exe
```

Important:

- `pacman` works in **MSYS2 UCRT64**, not in PowerShell.
- PowerShell path: `C:\Users\Lukli\Downloads\...`
- MSYS2 path: `/c/Users/Lukli/Downloads/...`

---

## Build and run — Windows 10 32-bit

Use **MSYS2 MINGW32** shell. These commands are not PowerShell commands.

These commands assume you are already inside the project folder in the MSYS2 MINGW32 shell.

```bash
pacman -Syu
pacman -S --needed mingw-w64-i686-gcc mingw-w64-i686-cmake mingw-w64-i686-qt5-base

rm -rf build32
cmake -S . -B build32 -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build build32 -j

./build32/dosty-speak.exe
```

For deployment:

```bash
windeployqt build32/dosty-speak.exe
```

Notes:

- 32-bit Windows 10 is a target.
- Windows XP is not a target.
- 64-bit Windows should prefer the Qt 6 UCRT64 build.

---



### Reset now clears runtime data for testing

From version 0.2.22, the in-app reset removes:

- settings,
- phrases,
- downloaded voices,
- Piper runtime,
- bundled official Python runtime,
- generated audio/temp text files.

This makes repeated first-run testing cleaner.


## Reset setup / run the wizard again

Inside the app:

```text
View → Reset settings and open setup wizard…
```

This clears settings and phrases, then opens the first-run wizard again.

Downloaded Piper runtime and voice models are kept so they do not need to be downloaded again.

Manual reset commands:

### Linux

```bash
chmod +x scripts/reset-linux.sh
./scripts/reset-linux.sh
```

### macOS

```bash
chmod +x scripts/reset-macos.sh
./scripts/reset-macos.sh
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File scripts/reset-windows.ps1
```


## Quick troubleshooting

### Clean rebuild

Use this whenever the build behaves strangely:

```bash
rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

On macOS:

```bash
rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$(brew --prefix qt)"
cmake --build build -j"$(sysctl -n hw.ncpu)"
```















### Windows Piper bundled official Python runtime

Version 0.2.20 changes the Windows Piper installer to always use Dosty Speak's
bundled official Python runtime instead of depending on system Python.

When Piper is installed on Windows, Dosty Speak downloads:

```text
python-3.11.9-embed-amd64.zip
get-pip.py
```

into its own app data folder, enables `site-packages`, installs pip, and installs
`piper-tts` there.

This avoids Microsoft Store Python aliases and avoids requiring users to install
Python manually.


### Windows embedded Python for Piper

Version 0.2.19 can install a bundled official Python runtime for Dosty Speak on Windows.

If no usable system Python is found, the app downloads official Python embeddable ZIP into its own app data folder, bootstraps pip, and installs `piper-tts` there.

This means users do not need to install Python manually just to use Piper voices.


### Windows Piper Python detection fix

Version 0.2.18 improves Piper setup on Windows.

Instead of showing the Microsoft Store Python alias error, the app now probes several Python candidates first:

- `py -3`
- `python3`
- `python`
- Python installed in `%LOCALAPPDATA%\Programs\Python`
- `C:\msys64\ucrt64\bin\python.exe`
- `C:\msys64\mingw64\bin\python.exe`

Only after no working Python is found does it show one clear message.


### First-run text and Windows Piper Python fix

Version 0.2.17 removes the unnecessary "long options" note from the first-run wizard and widens setup/voice dialogs.

It also improves Piper setup on Windows:

- tries `py -3`,
- then `python3`,
- then `python`,
- then `C:\msys64\ucrt64\bin\python.exe`.

This avoids the Microsoft Store `python.exe` alias problem when possible.


### Windows missing DLL fix

Version 0.2.16 changes Windows deployment to copy all `.dll` files from
`C:\msys64\ucrt64\bin` into the deployment folder after `windeployqt`.

This is intentionally less minimal, but much more reliable for MSYS2-built Qt apps.

If you see errors like:

```text
Qt6Core.dll was not found
libstdc++-6.dll was not found
libgcc_s_seh-1.dll was not found
```

do not run `build\dosty-speak.exe`.

Run the deployed app instead:

```powershell
.\dist\DostySpeak-Windows-x86_64\dosty-speak.exe
```

or double-click:

```text
dist\DostySpeak-Windows-x86_64\run-dosty-speak.cmd
```

The build helper now automatically runs the deployment helper after a successful build.


### Windows DLL deployment fix

Version 0.2.15 improves Windows deployment.

If the raw `build\dosty-speak.exe` shows an error like:

```text
Qt6Core.dll was not found
Qt6Gui.dll was not found
```

that is expected for an undeployed Qt build. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-windows-powershell.ps1
```

Then start:

```powershell
.\dist\DostySpeak-Windows-x86_64\dosty-speak.exe
```

The deploy helper now runs `windeployqt` and also copies MSYS2/UCRT runtime DLLs recursively.


### Windows Ninja build fix

Version 0.2.14 switches the Windows helper from `MinGW Makefiles` to `Ninja`.

If you saw:

```text
CMake was unable to find a build program corresponding to "MinGW Makefiles"
CMAKE_MAKE_PROGRAM is not set
CMAKE_CXX_COMPILER not set
```

use version 0.2.14 or newer. The helper now installs `mingw-w64-ucrt-x86_64-ninja`
and builds with:

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
```


### Windows MSYS2 runtime update fix

Version 0.2.13 handles the normal MSYS2 behavior where `msys2-runtime` or `pacman`
updates terminate all MSYS2 processes.

If you saw something like:

```text
:: To complete this update all MSYS2 processes including this terminal will be closed.
SUCCESS: The process with PID ... has been terminated.
MSYS2 build failed with exit code 1
```

use version 0.2.13 or newer. The PowerShell helper now runs the MSYS2 update
in a separate phase, allows that phase to end non-zero, then starts a fresh
MSYS2 process for dependency install and build.


### Windows PowerShell project script fix

Version 0.2.12 changes the Windows PowerShell helper again: instead of generating
a temp script that has to `cd` to the project path, it writes a temporary
`.dosty-build-msys2.sh` file directly into the project folder and lets bash
detect its own directory.

If you saw:

```text
/c/Users/.../dosty-speak: Is a directory
```

use version 0.2.12 or newer.


### Windows PowerShell newline path fix

Version 0.2.11 fixes the Windows build helper so MSYS2 paths are trimmed and bash-quoted before being written into the temporary build script.

If you saw something like:

```text
cd: $'\n/c/Users/.../dosty-speak\n': No such file or directory
```

use version 0.2.11 or newer.

The helper now also fails properly when MSYS2 build fails, instead of printing a fake success message.


### Windows PowerShell temp path fix

Version 0.2.10 fixes the Windows build helper so it no longer calls `Resolve-Path`
on a temporary script before that file exists.

If you saw:

```text
Resolve-Path : Cannot find path ... dosty-speak-build-....sh because it does not exist.
```

use version 0.2.10 or newer.


### Windows PowerShell quoting fix

Version 0.2.9 rewrites the Windows PowerShell helper to avoid fragile double-quoted strings.
If you saw:

```text
The string is missing the terminator: ".
```

use version 0.2.9 or newer.


### Windows PowerShell script parser fix

Version 0.2.8 fixes the PowerShell helper so bash commands such as `pacman -Syu --noconfirm || true` are no longer parsed by PowerShell.

If you saw:

```text
The token '||' is not a valid statement separator in this version.
```

use version 0.2.8 or newer and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-powershell.ps1
```


### Windows: pacman is not recognized

You are running MSYS2 commands in PowerShell.

This will fail:

```powershell
pacman -Syu
```

Use one of these instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-powershell.ps1
```

or open **MSYS2 UCRT64** and run the `pacman` commands there.


### Linux: command not found after install

```bash
export PATH="$HOME/.local/bin:$PATH"
dosty-speak
```

### Reset app data

This removes saved phrases/settings and regenerates clean defaults:

```bash
rm -rf ~/.local/share/Dosty/DostySpeak
```

---




## Piper setup robustness

Version 0.2.6 makes Piper setup more defensive:

- if Piper runtime already exists, the app reuses it,
- if the selected voice model already exists, the app simply selects it,
- if the voice catalog resource is missing, the app has built-in fallback Piper voices,
- selecting a Piper voice from the wizard or voice dialog now forces engine/model settings to be saved.


## First-run Piper fix

Version 0.2.5 fixes the setup/reset wizard path:

- when you reset settings and choose a Piper voice, the app now installs/repairs Piper,
- downloads the selected voice model,
- saves Piper as the active engine,
- and stores the selected model path immediately.



### Automatic system theme detection

On first run, Dosty Speak now uses the operating system palette to choose the initial light/dark mode.

The first-run wizard and settings dialog also apply the selected appearance immediately, so the dropdown no longer feels stale after switching theme.


## First launch wizard

On first launch, Dosty Speak asks for:

- interface language,
- initial voice,
- light or dark mode.

The language and appearance are applied immediately without requiring an app restart.

If you choose a Piper voice, the app can immediately:

1. install/repair Piper runtime,
2. download the selected Piper voice model,
3. configure the app to use that voice.

You can also skip Piper during first launch and use:

```text
Voice → Install / repair Piper runtime…
Voice → Select / download voice…
```

later.


## Piper voices

Dosty Speak can install/repair Piper runtime from inside the app:

```text
Voice → Install / repair Piper runtime…
```

Then download a voice model:

```text
Voice → Select / download voice…
```

Requirements:

- Linux: `python3` and `python3-venv`
- macOS: Python 3, recommended through Homebrew
- Windows: Python available as `python`

Native speech still works without Piper:

- Linux: `espeak-ng`
- macOS: `say`
- Windows: `System.Speech`

---

## Keyboard workflow

- `Enter` in the input field: speak the current text
- `Shift+Enter` in the input field: save text as phrase
- `Tab`: switch between typing and phrase selection
- Arrow keys in phrase list: select phrase
- `Enter` in phrase list: speak selected phrase
- `1–9` in phrase list: select visible phrase
- `Alt+1–9`: speak visible phrase from anywhere
- `Delete` in phrase list: delete selected phrase
- `Ctrl+F`: search
- `Ctrl+D`: dark mode
- Right-click folder: rename/delete folder
- Right-click phrase: phrase actions

---

## Diagnostics

Use:

```text
Help → Diagnostics…
```

It shows:

- app version
- build type and build date
- compiler
- Qt build/runtime version
- operating system
- CPU architecture
- app data/resource paths

Use the **Copy** button and paste the output into GitHub issues.

---

## GitHub Releases

Recommended files to upload:

```text
DostySpeak-linux-x86_64.AppImage
DostySpeak-ubuntu-amd64.deb
DostySpeak-linux-i386.tar.gz
DostySpeak-windows-x86_64.zip
DostySpeak-windows-i686.zip
DostySpeak-macos-arm64.dmg
DostySpeak-macos-x86_64.dmg
```

Important:

- Build each platform on that platform when possible.
- Windows/macOS need Qt deployment tools.
- Do not upload only a raw `.exe` unless dependencies are bundled.
- Piper voice models are large; the app can download them, so they do not need to be bundled by default.

---

## Project structure

```text
.
├── CMakeLists.txt
├── src/
├── resources/
│   ├── i18n/
│   └── voices/
├── scripts/
├── packaging/
├── AUTHORS.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── NOTICE.md
├── README.md
└── THIRD_PARTY_NOTICES.md
```

---

## GitHub quick start

```bash
git init
git add .
git commit -m "Initial Dosty Speak release"
git branch -M main
git remote add origin git@github.com:<user>/dosty-speak.git
git push -u origin main
```





### Windows installer license encoding and x86 PATH fix

Version 0.2.32 fixes two Windows release issues:

- NSIS now uses `packaging/windows/LICENSE-installer.txt`, an ASCII-safe installer license file, so the author name is not garbled on the license page.
- x86 generated MSYS2 scripts now set `/usr/bin` in `PATH` before calling `pacman`/`grep`.

There is also a new note about GUI toolkit alternatives:

```text
docs/GUI_TOOLKIT_OPTIONS.md
```

For real 32-bit Windows support, wxWidgets is probably a better long-term choice than Qt.


### Windows x86 path fix v2

Version 0.2.31 fixes the x86 build helper again.

Instead of using `dirname "$0"` inside the generated bash script, PowerShell now passes the MSYS project path as the first argument:

```bash
PROJECT_DIR="$1"
cd "$PROJECT_DIR"
```

This avoids both previous failures:

```text
dirname: command not found
cd: null directory
```


### Windows x86 path quoting fix

Version 0.2.30 fixes the x86 build script path issue.

The generated x86 shell script is now written directly into the project folder and uses:

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
```

So it no longer tries to run a broken command like:

```text
cd: $'\n/c/Users/.../dosty-speak\n': No such file or directory
```

This same self-location pattern is also used for the arm64 helper.


### Windows x86 toolchain switch

Version 0.2.29 changes the Windows x86 build strategy.

Instead of relying only on the old `MINGW32` repository, the builder now tries:

1. `CLANG32 + Qt 6`
2. `CLANG32 + Qt 5`
3. `MINGW32 + Qt 5`
4. `MINGW32 + Qt 6`

This means 32-bit Windows builds are no longer blocked just because `mingw-w64-i686-qt5-base` is missing from `MINGW32`.

The x86 release path can now create:

```text
dist\DostySpeak-Portable-x86.zip
dist\DostySpeak-Setup-x86.exe
```

if a usable 32-bit Qt toolchain is available.


### Windows x86 reality check

Version 0.2.28 makes Windows x86 handling clearer.

On your current MSYS2 installation, this package is missing:

```text
mingw-w64-i686-qt5-base
```

That means Windows 32-bit Qt builds cannot be produced from the standard current MSYS2 repositories on your machine. The script now detects this and skips x86 cleanly instead of failing halfway.

You can check x86 support manually:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-windows-x86-support.ps1
```

Recommended release path now:

- Windows: ship `amd64` installer + portable ZIP
- 32-bit work: optimize and test on 32-bit Linux first
- Windows x86 later: use older archived Qt 5 toolchain, MXE, or a dedicated CI/toolchain if really needed

Experimental Linux i386 helper:

```bash
chmod +x scripts/build-linux-i386.sh
./scripts/build-linux-i386.sh
```

Run it inside a real 32-bit/i386 Linux environment or container.



### Legacy FLTK GUI for older hardware

Version 0.2.33 adds an experimental lightweight FLTK GUI in:

```text
legacy-fltk/
```

This is meant as the first step toward an old-hardware / 32-bit friendly frontend.
It is much smaller than Qt and is a better candidate for future 32-bit Windows/Linux builds.

Build on Linux:

```bash
chmod +x scripts/build-legacy-fltk-linux.sh
./scripts/build-legacy-fltk-linux.sh
```

### Voice performance and volume settings

Settings now include:

- playback volume,
- Piper quality/speed preset:
  - Fast / weaker CPU,
  - Balanced,
  - Higher quality / slower.

For weak CPUs, use the Fast preset. Piper can still be slow with medium models, but this gives a quick user-facing control and prepares the app for low-quality/fast voice models later.


### Windows x86 legacy fallback

Version 0.2.34 changes the x86 build path:

1. Try Qt x86 first.
2. If Qt x86 is unavailable, try the lightweight `legacy-fltk` GUI.
3. If FLTK is available, create:

```text
dist\DostySpeak-Legacy-Portable-x86.zip
```

This is the practical path for older 32-bit Windows hardware while the main Qt app remains the modern 64-bit build.


### Piper playback reliability fix on Windows

Version 0.2.35 reverts Windows WAV playback to the reliable `System.Media.SoundPlayer` path.

The previous Windows volume implementation used WPF `MediaPlayer`, which can fail or hang on some machines. Piper could generate audio but then not actually play it.

Now:

- Piper still generates `last.wav`,
- Windows plays it through `SoundPlayer.PlaySync()`,
- if Piper itself fails, details are written to:

```text
piper-last-error.txt
```

and included in diagnostics.

The GUI volume setting remains, but on Windows WAV playback currently follows the system mixer volume. macOS/Linux can apply per-playback volume more directly.

### Windows x86 status

If your MSYS2 has no `clang32`, no i686 Qt and no i686 FLTK, the x86 build cannot produce a GUI binary from that toolchain. See:

```text
docs/WINDOWS_X86_NOTES.md
```


### Windows console window fix

Version 0.2.36 fixes the extra CMD/terminal window on Windows.

The application is now built as a Windows GUI subsystem app by passing `WIN32`
to `add_executable` on Windows. PowerShell helper processes used for speech
playback are also started with `CREATE_NO_WINDOW`.

This prevents a console window from appearing whenever `dosty-speak.exe` is launched.


### Pure Win32 x86 fallback

Version 0.2.37 adds a pure Win32 legacy x86 fallback.

If Qt x86 and FLTK x86 are both unavailable, the x86 builder now compiles:

```text
legacy-win32/main.cpp
```

directly with `mingw-w64-i686-gcc`.

This produces:

```text
dist\DostySpeak-Legacy-Win32-Portable-x86.zip
```

It is a simpler old-hardware frontend using Windows SAPI directly. It has fewer features than the Qt app, but it does not need Qt, FLTK, Python, Piper, or any GUI toolkit package.


### Windows x86 simplified to pure Win32

Version 0.2.38 removes Qt/FLTK probing from the Windows x86 release path.

The x86 build now directly builds the lightweight pure Win32 legacy frontend:

```text
legacy-win32/main.cpp
```

It uses static GCC linking:

```text
-static -static-libgcc -static-libstdc++
```

so the generated EXE should no longer require DLLs like:

```text
libgcc_s_dw2-1.dll
libstdc++-6.dll
```

Output:

```text
dist\DostySpeak-Legacy-Win32-Portable-x86.zip
```


### Keyboard controls and main sliders

Version 0.2.39 improves both frontends:

- 32-bit Win32 legacy:
  - Tab switches between the input field and phrase list,
  - Enter reads the input field or selected phrase,
  - the hint text now describes this behavior.

- 64-bit Qt:
  - volume slider is visible directly in the main GUI,
  - speed slider is visible directly in the main GUI.

Important Piper note: the speed/quality preset changes how the generated speech sounds and plays, but real generation time mostly depends on the model size. For weak CPUs, use a `low / rychlejší` Piper voice instead of a `medium` voice.


### Terminal release builder

Version 0.2.40 adds an interactive terminal release builder:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release-terminal.ps1
```

It asks what you want to build directly in the terminal:

- amd64 / x86_64,
- x86 / 32-bit legacy Win32,
- arm64,
- installer EXE,
- portable ZIP.

After selection, it runs the normal build scripts in the same terminal, so you see the full detailed build output instead of hiding it behind a small Windows GUI.

The old checkbox GUI still exists, but the terminal builder is now the recommended Windows release workflow.


### UI and release builder polish

Version 0.2.41 cleans up several rough edges:

- removed the visible Piper generation-speed warning from the main GUI,
- added a proper `Folders/Složky` label above the folder list,
- changed the phrase table header to `Hlášky`,
- replaced the shortcuts message box with a cleaner scrollable dialog,
- sorted downloadable voices alphabetically by language/name,
- added more Piper voice entries and more low/faster voices,
- cleaned up the terminal release builder text,
- fixed a duplicate PowerShell `param(...)` block in the installer builder.


### Application icon

Version 0.2.42 adds a real Dosty Speak app icon for all platforms.

Included assets:

```text
resources/icons/dosty-speak.png
resources/icons/dosty-speak.ico
resources/icons/dosty-speak.icns
```

Platform integration:

- Windows executable resource icon,
- NSIS installer icon,
- Linux desktop file icon,
- macOS bundle icon.

The 32-bit/legacy and 64-bit builds share the same branding assets.


### Windows terminal encoding fix

Version 0.2.43 improves Windows PowerShell/terminal output.

The build scripts now set the console to UTF-8:

```powershell
chcp 65001
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
```

The interactive release builder also uses mostly ASCII output text, because classic Windows PowerShell and some terminals can still render UTF-8 inconsistently depending on font and code page.


### About dialog and repository images

Version 0.2.44 adds branding polish:

- the About dialog now shows the Dosty Speak photo/icon,
- GitHub README displays the app logo,
- `.github/assets/social-preview.png` is included for the GitHub repository social preview,
- folder and phrase section headings now use the same QLabel style instead of mixing QLabel and table header styling.


### Transparent logo and Linux release builder

Version 0.2.45 updates the branding and Linux build tooling:

- replaced the app icon everywhere with a transparent-background logo without text,
- regenerated PNG/ICO/ICNS icon assets,
- updated the README logo and GitHub social preview image,
- added an interactive Linux release builder:

```bash
chmod +x scripts/build-linux-release-terminal.sh
./scripts/build-linux-release-terminal.sh
```

The Linux builder lets you choose:

- x86_64 / amd64,
- i386 / 32-bit, when running inside a real 32-bit Linux environment,
- portable tar.gz,
- DEB,
- RPM.

Note: 32-bit Linux builds should be done in a real 32-bit chroot/container/VM because Qt multiarch cross-builds are unreliable.


### Windows reinstall fix

Version 0.2.46 improves reinstall/upgrade behavior on Windows.

The NSIS installer now:

- closes running `dosty-speak.exe` before copying files,
- closes the 32-bit legacy executable if it is running,
- enables overwrite mode,
- deletes known locked runtime DLLs before copying,
- schedules locked files for replacement/removal on reboot when needed.

This fixes reinstall errors such as:

```text
Error opening file for writing:
C:\Program Files\Dosty Speak\Qt6Core.dll
```

That usually happens when the previous Dosty Speak instance is still running and Windows keeps Qt DLLs locked.


### Linux builder dependency install

Version 0.2.47 improves the Linux release builder.

If a required build tool is missing, for example `ninja`, the builder now offers to install build dependencies automatically with `sudo`.

You can also install them directly:

```bash
chmod +x scripts/install-linux-build-deps.sh
./scripts/install-linux-build-deps.sh
```

Then run:

```bash
./scripts/build-linux-release-terminal.sh
```


### macOS bundle install fix

Version 0.2.48 fixes macOS builds after enabling `MACOSX_BUNDLE`.

CMake now installs app bundles correctly:

```cmake
install(TARGETS dosty-speak
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
```

The macOS installer script now copies the generated `.app` bundle instead of expecting a raw `build/dosty-speak` executable.

Run:

```bash
chmod +x scripts/install-macos.sh
./scripts/install-macos.sh
open "$HOME/Applications/Dosty Speak.app"
```

There is also a release helper:

```bash
chmod +x scripts/build-macos-release-terminal.sh
./scripts/build-macos-release-terminal.sh
```


### macOS first-run crash fix

Version 0.2.49 fixes a macOS bundle packaging issue.

The app resources were being copied into:

```text
Dosty Speak.app/Contents/MacOS/resources
```

That can break `macdeployqt` / codesign and can make the app close immediately on launch.

Resources now go into the correct bundle location:

```text
Dosty Speak.app/Contents/Resources/resources
```

The macOS installer now also:

- removes old broken `Contents/MacOS/resources`,
- runs `macdeployqt` before the final resource copy,
- removes extended attributes with `xattr -cr`,
- ad-hoc signs the finished app bundle.

Run:

```bash
chmod +x scripts/install-macos.sh
./scripts/install-macos.sh
open "$HOME/Applications/Dosty Speak.app"
```

If it still closes immediately, run:

```bash
chmod +x scripts/debug-macos-run.sh
./scripts/debug-macos-run.sh
```

and send the output.
