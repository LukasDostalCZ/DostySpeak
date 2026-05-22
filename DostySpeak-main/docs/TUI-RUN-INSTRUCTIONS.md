# Dosty Speak TUI run instructions

All normal builds should be started through the platform terminal builder.

## macOS

```bash
cd ~/Dev/dosty-speak
chmod +x scripts/*.sh
./scripts/build-terminal-macos.sh
```

## Windows 10 LTSC 2019 / Windows 11

Open Windows PowerShell in the project directory and run:

```powershell
cd $env:USERPROFILE\Desktop\dosty-speak
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```

If the project is in `Dev` instead of Desktop:

```powershell
cd $env:USERPROFILE\Dev\dosty-speak
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```

## Linux

```bash
cd ~/Dev/dosty-speak
chmod +x scripts/*.sh
./scripts/build-terminal-linux.sh
```

The Linux TUI can build the desktop app and create packages.

Direct package build without the menu:

```bash
./scripts/build-linux-packages.sh both
```

Outputs:

```text
dist/linux/
```

## Git check before push

```bash
git status
git diff --stat
```

Then commit:

```bash
git add .
git commit -m "Sync Linux terminal builder with macOS and add DEB/RPM packaging"
git push
```
