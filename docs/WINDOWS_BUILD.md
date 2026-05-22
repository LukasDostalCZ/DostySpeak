# Windows build

## Requirements

Install manually:

- MSYS2: https://www.msys2.org/
- NSIS: https://nsis.sourceforge.io/Download

The scripts do not require `winget`. This matters on Windows 10 2019 LTSC where `winget` may be missing.

## Build

Run from the project folder in Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release-terminal.ps1
```

## Clean build

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clean-windows-build.ps1
```

## Outputs

```text
dist\DostySpeak-Setup-x64.exe
dist\DostySpeak-Portable-x64.zip
dist\DostySpeak-Legacy-Win32-Portable-x86.zip
```

## Windows 32-bit

The 32-bit build is a lightweight legacy Win32 frontend. It does not use Qt, Piper or Python.
