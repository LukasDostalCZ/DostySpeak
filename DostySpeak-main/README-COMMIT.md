# Dosty Speak 0.3.61 commit notes

This zip is a full repository snapshot based on the supplied git version.

Main fixes:

- Linux terminal builder is no longer the old plain menu.
- Linux TUI now uses the same Python/curses style as the macOS terminal builder.
- Linux TUI includes DEB/RPM packaging options.
- Version is read from the single `VERSION` file.
- `build-linux-packages.sh` can build:
  - Linux desktop app
  - DEB package
  - RPM package
  - both DEB and RPM
- CPack packaging is wired from `cmake/DostyPackaging.cmake`.

Recommended commit:

```bash
git status
git diff --stat
git add .
git commit -m "Sync Linux TUI with macOS builder and add DEB/RPM packaging"
git push
```

Run builders:

```bash
# macOS
./scripts/build-terminal-macos.sh

# Linux
./scripts/build-terminal-linux.sh

# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```
