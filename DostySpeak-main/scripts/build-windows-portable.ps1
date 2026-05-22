# Dosty Speak - Windows portable ZIP builder
# Run from project folder:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-portable.ps1

$ErrorActionPreference = "Stop"

$ProjectDir = (Resolve-Path ".").Path
$DistRoot = Join-Path $ProjectDir "dist"
$DeployDir = Join-Path $DistRoot "DostySpeak-Windows-x86_64"
$PortableOut = Join-Path $DistRoot "DostySpeak-Portable-x64.zip"

if (!(Test-Path (Join-Path $DeployDir "dosty-speak.exe"))) {
    Write-Host "Deployment folder not found. Building and deploying first..."
    powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-powershell.ps1")
}

if (Test-Path $PortableOut) {
    Remove-Item -Force $PortableOut
}

Compress-Archive -Path (Join-Path $DeployDir "*") -DestinationPath $PortableOut

Write-Host ""
Write-Host "Portable ZIP created:"
Write-Host ("  " + $PortableOut)
