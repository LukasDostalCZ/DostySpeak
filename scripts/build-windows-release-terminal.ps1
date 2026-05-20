# Dosty Speak - Windows terminal release builder
# Run from project folder:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release-terminal.ps1

# Keep Windows PowerShell console output readable with UTF-8 text.
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::now($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::now($false)
    chcp 65001 | Out-Null
} catch {
    # Non-fatal on older shells.
}

$ErrorActionPreference = "Stop"

$ProjectDir = (Resolve-Path ".").Path

function Ask-YesNo([string]$Question, [bool]$DefaultYes = $true) {
    while ($true) {
        $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
        $answer = Read-Host "$Question $suffix"

        if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultYes }

        switch ($answer.Trim().ToLowerInvariant()) {
            "y" { return $true }
            "yes" { return $true }
            "a" { return $true }
            "yes" { return $true }
            "n" { return $false }
            "no" { return $false }
            "no" { return $false }
            default { Write-Host "Please answer y/n, or press Enter for the default." -ForegroundColor Yellow }
        }
    }
}

function Section([string]$Text) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}

Clear-Host
Write-Host "Dosty Speak - Windows release builder" -ForegroundColor Cyan
Write-Host ""
Write-Host "Choose what to build. After confirmation, the full detailed build log is printed here."
Write-Host ""

Write-Host "Architectures:"
Write-Host "  1) amd64 / x86_64  - main modern Qt app"
Write-Host "  2) x86 / 32-bit    - lightweight legacy Win32 app for older Windows"
Write-Host "  3) arm64           - Windows ARM64 only"
Write-Host ""

$buildAmd64 = Ask-YesNo "Build amd64 / x86_64?" $true
$buildX86 = Ask-YesNo "Build x86 / 32-bit legacy Win32?" $false
$buildArm64 = Ask-YesNo "Build arm64? Works only on Windows ARM64." $false

if (-not ($buildAmd64 -or $buildX86 -or $buildArm64)) {
    Write-Host "Nothing selected. Exiting." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Artifacts:"
$wantInstaller = Ask-YesNo "Create installer EXE where supported?" $true
$wantPortable = Ask-YesNo "Create portable ZIP?" $true

if (-not ($wantInstaller -or $wantPortable)) {
    Write-Host "No artifact type selected. Exiting." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
if ($buildAmd64) { Write-Host "  amd64: main Qt app" }
if ($buildX86) { Write-Host "  x86: legacy Win32 app" }
if ($buildArm64) { Write-Host "  arm64: Windows ARM64 build" }
Write-Host ("  Installer EXE: " + ($(if ($wantInstaller) { "yes" } else { "no" })))
Write-Host ("  Portable ZIP:  " + ($(if ($wantPortable) { "yes" } else { "no" })))

if (-not (Ask-YesNo "Continue?" $true)) {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

$artifactArgs = @()
if ($wantInstaller) { $artifactArgs += "-Installer" }
if ($wantPortable) { $artifactArgs += "-Portable" }

if ($buildAmd64) {
    Section "Building amd64 / x86_64"
    powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-release.ps1") -Arch amd64 @artifactArgs
}

if ($buildX86) {
    Section "Building x86 / 32-bit legacy Win32"
    powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-release.ps1") -Arch x86 -Portable
}

if ($buildArm64) {
    Section "Building arm64"
    powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-release.ps1") -Arch arm64 @artifactArgs
}

Section "Done"
Write-Host "Outputs are in:"
Write-Host "  $ProjectDir\dist"
Write-Host ""
Write-Host "Typical files:"
Write-Host "  DostySpeak-Setup-x64.exe"
Write-Host "  DostySpeak-Portable-x64.zip"
Write-Host "  DostySpeak-Legacy-Win32-Portable-x86.zip"
