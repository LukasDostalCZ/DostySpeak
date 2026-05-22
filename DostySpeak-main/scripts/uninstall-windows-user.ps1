# Dosty Speak - Windows user uninstaller
$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\DostySpeak"
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Dosty Speak.lnk"
$StartMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Dosty Speak"

Remove-Item -Recurse -Force $InstallDir -ErrorAction SilentlyContinue
Remove-Item -Force $DesktopShortcut -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $StartMenuDir -ErrorAction SilentlyContinue

Write-Host "Dosty Speak was removed."
