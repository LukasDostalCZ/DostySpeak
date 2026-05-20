# Dosty Speak - Windows user installer
# Run from the project folder after deployment:
#   powershell -ExecutionPolicy Bypass -File .\scripts\install-windows-user.ps1
#
# Installs the deployed app into %LOCALAPPDATA%\Programs\DostySpeak
# and creates Desktop + Start Menu shortcuts.

$ErrorActionPreference = "Stop"

$ProjectDir = (Resolve-Path ".").Path
$Source = Join-Path $ProjectDir "dist\DostySpeak-Windows-x86_64"

if (!(Test-Path (Join-Path $Source "dosty-speak.exe"))) {
    Write-Host "Deployment folder not found."
    Write-Host "Create it first:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\deploy-windows-powershell.ps1"
    exit 1
}

$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\DostySpeak"
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Dosty Speak.lnk"
$StartMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Dosty Speak"
$StartMenuShortcut = Join-Path $StartMenuDir "Dosty Speak.lnk"

if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $Source "*") $InstallDir

New-Item -ItemType Directory -Force -Path $StartMenuDir | Out-Null

$TargetExe = Join-Path $InstallDir "dosty-speak.exe"

$Shell = New-Object -ComObject WScript.Shell

$Shortcut = $Shell.CreateShortcut($DesktopShortcut)
$Shortcut.TargetPath = $TargetExe
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "Dosty Speak"
$Shortcut.Save()

$Shortcut = $Shell.CreateShortcut($StartMenuShortcut)
$Shortcut.TargetPath = $TargetExe
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.Description = "Dosty Speak"
$Shortcut.Save()

Write-Host ""
Write-Host "Dosty Speak installed to:"
Write-Host ("  " + $InstallDir)
Write-Host ""
Write-Host "Desktop shortcut:"
Write-Host ("  " + $DesktopShortcut)
Write-Host ""
Write-Host "Start Menu shortcut:"
Write-Host ("  " + $StartMenuShortcut)
Write-Host ""
Write-Host "Run:"
Write-Host ("  " + $TargetExe)
