# Dosty Speak TUI run instructions

These commands start the terminal builder menu for each platform.
Run them from the root of the Dosty Speak repository.

## macOS

```bash
cd ~/Dev/dosty-speak
chmod +x scripts/build-terminal-macos.sh
./scripts/build-terminal-macos.sh
```

## Windows 10 / 11 PowerShell

If the project is on Desktop:

```powershell
cd $env:USERPROFILE\Desktop\dosty-speak
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```

If the project is in Dev:

```powershell
cd $env:USERPROFILE\Dev\dosty-speak
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```

## Linux

```bash
cd ~/Dev/dosty-speak
chmod +x scripts/build-terminal-linux.sh scripts/build-linux-packages.sh scripts/apply-linux-packaging-fix.sh
./scripts/build-terminal-linux.sh
```

Direct Linux package build without the menu:

```bash
./scripts/build-linux-packages.sh both
```

Outputs are created in:

```text
dist/linux/
```

## Commit and push

```bash
git status
git diff
git add CMakeLists.txt VERSION cmake/DostyPackaging.cmake scripts/build-terminal-linux.sh scripts/build-linux-packages.sh scripts/apply-linux-packaging-fix.sh docs/TUI-RUN-INSTRUCTIONS.md README-COMMIT.md
git commit -m "Add Linux DEB and RPM packaging"
git push
```
