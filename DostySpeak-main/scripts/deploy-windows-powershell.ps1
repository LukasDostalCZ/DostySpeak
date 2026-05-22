# Dosty Speak - Windows deployment helper
# Run from the project folder after building:
#   powershell -ExecutionPolicy Bypass -File .\scripts\deploy-windows-powershell.ps1
#
# This creates a runnable folder and ZIP for GitHub Releases.

# Keep Windows PowerShell console output readable with UTF-8 text.
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 | Out-Null
} catch {
    # Non-fatal on older shells.
}

$ErrorActionPreference = "Stop"

$ProjectDir = (Resolve-Path ".").Path
$Exe = Join-Path $ProjectDir "build\dosty-speak.exe"

if (!(Test-Path $Exe)) {
    Write-Host "Executable not found:"
    Write-Host ("  " + $Exe)
    Write-Host "Build first:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-powershell.ps1"
    exit 1
}

$MsysRoot = "C:\msys64"
$UcrtBin = Join-Path $MsysRoot "ucrt64\bin"
$Windeploy = Join-Path $UcrtBin "windeployqt.exe"

if (!(Test-Path $Windeploy)) {
    Write-Host "windeployqt not found:"
    Write-Host ("  " + $Windeploy)
    Write-Host "Make sure MSYS2 UCRT64 Qt is installed."
    exit 1
}

$DistRoot = Join-Path $ProjectDir "dist"
$Dist = Join-Path $DistRoot "DostySpeak-Windows-x86_64"

if (Test-Path $Dist) {
    Remove-Item -Recurse -Force $Dist
}
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

Copy-Item $Exe $Dist

# Resources are required for translations and voice catalog.
if (Test-Path (Join-Path $ProjectDir "build\resources")) {
    Copy-Item -Recurse -Force (Join-Path $ProjectDir "build\resources") $Dist
} elseif (Test-Path (Join-Path $ProjectDir "resources")) {
    Copy-Item -Recurse -Force (Join-Path $ProjectDir "resources") (Join-Path $Dist "resources")
}

Write-Host "Running windeployqt..."
& $Windeploy (Join-Path $Dist "dosty-speak.exe") --release

Write-Host "Copying MSYS2/UCRT runtime DLLs..."

# MSYS2/MinGW applications also need GCC/UCRT/standard library DLLs.
# windeployqt is good for Qt plugins, but it often does not copy everything
# needed by MSYS2-built executables. Copying UCRT64 DLLs is larger, but reliable.
Get-ChildItem -Path $UcrtBin -Filter "*.dll" -File | ForEach-Object {
    Copy-Item $_.FullName $Dist -Force
}

# Also copy the EXE again after deployment just in case.
Copy-Item $Exe $Dist -Force

# Create a small runner script for users who open the folder.
$RunCmd = Join-Path $Dist "run-dosty-speak.cmd"
@"
@echo off
cd /d "%~dp0"
start "" "dosty-speak.exe"
"@ | Set-Content -Encoding ASCII $RunCmd

$InstallCmd = Join-Path $Dist "install-dosty-speak.cmd"
@"
@echo off
cd /d "%~dp0\..\.."
powershell -ExecutionPolicy Bypass -File ".\scripts\install-windows-user.ps1"
pause
"@ | Set-Content -Encoding ASCII $InstallCmd

$Zip = Join-Path $DistRoot "DostySpeak-Windows-x86_64.zip"
if (Test-Path $Zip) {
    Remove-Item -Force $Zip
}
Compress-Archive -Path (Join-Path $Dist "*") -DestinationPath $Zip

Write-Host ""
Write-Host "Deployment folder:"
Write-Host ("  " + $Dist)
Write-Host ""
Write-Host "Run this, not the raw build exe:"
Write-Host "  .\dist\DostySpeak-Windows-x86_64\dosty-speak.exe"
Write-Host ""
Write-Host "Or double-click:"
Write-Host "  dist\DostySpeak-Windows-x86_64\run-dosty-speak.cmd"
Write-Host ""
Write-Host "Release ZIP:"
Write-Host ("  " + $Zip)
