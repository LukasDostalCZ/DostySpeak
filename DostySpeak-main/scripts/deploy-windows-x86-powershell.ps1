# Dosty Speak - Windows x86 deployment helper
# Creates portable x86 ZIP from Qt or legacy FLTK build.

param(
    [ValidateSet("clang32", "mingw32")]
    [string]$Toolchain = "mingw32",

    [switch]$Legacy
)

$ErrorActionPreference = "Stop"

$ProjectDir = (Resolve-Path ".").Path

if ($Legacy) {
    $BuildDir = Join-Path $ProjectDir "build-x86-legacy"
    $Exe = Join-Path $BuildDir "dosty-speak-legacy.exe"
    $DistName = "DostySpeak-Legacy-Windows-x86"
    $ZipName = "DostySpeak-Legacy-Portable-x86.zip"
} else {
    $BuildDir = Join-Path $ProjectDir "build-x86"
    $Exe = Join-Path $BuildDir "dosty-speak.exe"
    $DistName = "DostySpeak-Windows-x86"
    $ZipName = "DostySpeak-Portable-x86.zip"
}

if (!(Test-Path $Exe)) {
    throw "x86 executable was not found: $Exe"
}

$MsysRoot = "C:\msys64"

if ($Toolchain -eq "clang32") {
    $BinDir = Join-Path $MsysRoot "clang32\bin"
} else {
    $BinDir = Join-Path $MsysRoot "mingw32\bin"
}

$Windeploy = Join-Path $BinDir "windeployqt.exe"

$DistRoot = Join-Path $ProjectDir "dist"
$Dist = Join-Path $DistRoot $DistName

if (Test-Path $Dist) {
    Remove-Item -Recurse -Force $Dist
}
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

Copy-Item $Exe $Dist

if (!$Legacy -and (Test-Path (Join-Path $ProjectDir "resources"))) {
    Copy-Item -Recurse -Force (Join-Path $ProjectDir "resources") (Join-Path $Dist "resources")
}

if (!$Legacy -and (Test-Path $Windeploy)) {
    & $Windeploy (Join-Path $Dist "dosty-speak.exe") --release
}

Get-ChildItem -Path $BinDir -Filter "*.dll" -File | ForEach-Object {
    Copy-Item $_.FullName $Dist -Force
}

$RunCmd = Join-Path $Dist "run-dosty-speak.cmd"
$ExeName = Split-Path $Exe -Leaf
@"
@echo off
cd /d "%~dp0"
start "" "$ExeName"
"@ | Set-Content -Encoding ASCII $RunCmd

$Zip = Join-Path $DistRoot $ZipName
if (Test-Path $Zip) {
    Remove-Item -Force $Zip
}
Compress-Archive -Path (Join-Path $Dist "*") -DestinationPath $Zip

Write-Host ""
Write-Host "x86 deployment folder:"
Write-Host ("  " + $Dist)
Write-Host ""
Write-Host "x86 portable ZIP:"
Write-Host ("  " + $Zip)
