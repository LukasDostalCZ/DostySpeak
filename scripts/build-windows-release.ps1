# Dosty Speak - Windows release builder CLI
# Examples:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -Arch amd64 -Installer -Portable
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -Arch x86 -Installer -Portable
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -Arch arm64 -Portable

param(
    [ValidateSet("amd64", "x86", "arm64")]
    [string]$Arch = "amd64",

    [switch]$Installer,
    [switch]$Portable
)

# Keep Windows PowerShell console output readable with UTF-8 text.
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 | Out-Null
} catch {
    # Non-fatal on older shells.
}

$ErrorActionPreference = "Stop"

if (-not $Installer -and -not $Portable) {
    $Installer = $true
    $Portable = $true
}

$ProjectDir = (Resolve-Path ".").Path
$MsysRoot = "C:\msys64"
$Bash = Join-Path $MsysRoot "usr\bin\bash.exe"

function Convert-ToMsysPath([string]$WindowsPath) {
    $Full = [System.IO.Path]::GetFullPath($WindowsPath).Trim()
    $Drive = $Full.Substring(0,1).ToLower()
    $Rest = $Full.Substring(2).Replace("\","/")
    return "/" + $Drive + $Rest
}

function Write-Utf8NoBomFile([string]$Path, [string[]]$Lines) {
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $Utf8NoBom)
}

function Run-MsysScript([string]$ScriptPath) {
    if (!(Test-Path $Bash)) { throw "MSYS2 not found at C:\msys64" }
    $ScriptMsys = Convert-ToMsysPath $ScriptPath
    & $Bash $ScriptMsys
    if ($LASTEXITCODE -ne 0) { throw "MSYS2 script failed with exit code $LASTEXITCODE" }
}

function Copy-AllDllsFrom([string]$BinDir, [string]$DistDir) {
    Get-ChildItem -Path $BinDir -Filter "*.dll" -File | ForEach-Object {
        Copy-Item $_.FullName $DistDir -Force
    }
}

function Build-Amd64 {
    powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-powershell.ps1")

    if ($Installer -or $Portable) {
        $args2 = @('-Arch','amd64')
        if ($Installer) { $args2 += '-Installer' }
        if ($Portable) { $args2 += '-Portable' }
        powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectDir "scripts\build-windows-installer.ps1") @args2
    }
}

function Build-X86 {
    Write-Host "x86 build selected."
    Write-Host "Building pure Win32 legacy frontend. No Qt/FLTK required."

    $MsysRoot = "C:\msys64"
    $Bash = Join-Path $MsysRoot "usr\bin\bash.exe"
    if (!(Test-Path $Bash)) { throw "MSYS2 not found at C:\msys64" }

    $Script = Join-Path $ProjectDir ".dosty-build-x86.sh"
    $ProjectMsys = Convert-ToMsysPath $ProjectDir

    Write-Utf8NoBomFile $Script @(
        '#!/usr/bin/env bash',
        'set -e',
        'PROJECT_DIR="$1"',
        'export PATH=/mingw32/bin:/usr/bin:$PATH',
        'export MSYSTEM=MINGW32',
        'cd "$PROJECT_DIR"',
        'echo "Current directory:"',
        'pwd',
        'echo "Building pure Win32 x86 legacy frontend..."',
        'if ! command -v g++ >/dev/null 2>&1; then',
        '  pacman -Syuu --noconfirm || true',
        '  pacman -S --needed --noconfirm mingw-w64-i686-gcc',
        'else',
        '  echo "MINGW32 g++ already available; skipping pacman install."',
        'fi',
        'rm -rf build-x86-win32',
        'mkdir -p build-x86-win32',
        'g++ -municode -mwindows -Os -s -static -static-libgcc -static-libstdc++ legacy-win32/main.cpp -o build-x86-win32/dosty-speak-legacy-win32.exe -lole32 -luuid -lcomctl32 -lsapi',
        'echo "mingw32" > build-x86-win32/toolchain.txt',
        'echo "legacy-win32" > build-x86-win32/build-kind.txt'
    )

    try {
        $ScriptMsys = Convert-ToMsysPath $Script
        & $Bash $ScriptMsys $ProjectMsys
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Host ''
            Write-Host 'x86 build failed. If the log contains PGP signature / unknown trust errors, run:'
            Write-Host '  powershell -ExecutionPolicy Bypass -File .\scripts\repair-msys2-keyring.ps1'
            throw "MSYS2 x86 Win32 build failed with exit code $code"
        }
    }
    finally {
        Remove-Item -Force $Script -ErrorAction SilentlyContinue
    }

    $Dist = Join-Path $ProjectDir "dist\DostySpeak-Legacy-Win32-x86"
    if (Test-Path $Dist) { Remove-Item -Recurse -Force $Dist }
    New-Item -ItemType Directory -Force -Path $Dist | Out-Null
    Copy-Item (Join-Path $ProjectDir "build-x86-win32\dosty-speak-legacy-win32.exe") $Dist

    $RunCmd = Join-Path $Dist "run-dosty-speak-legacy.cmd"
    '@echo off' | Set-Content -Encoding ASCII $RunCmd
    'cd /d "%~dp0"' | Add-Content -Encoding ASCII $RunCmd
    'start "" "dosty-speak-legacy-win32.exe"' | Add-Content -Encoding ASCII $RunCmd

    $Zip = Join-Path $ProjectDir "dist\DostySpeak-Legacy-Win32-Portable-x86.zip"
    if (Test-Path $Zip) { Remove-Item -Force $Zip }
    Compress-Archive -Path (Join-Path $Dist "*") -DestinationPath $Zip

    Write-Host ""
    Write-Host "Built pure Win32 legacy x86 portable package:"
    Write-Host ("  " + $Zip)
    Write-Host ""
    Write-Host "This x86 build does not use Qt, FLTK, Piper or Python."
    Write-Host "It uses Windows SAPI directly and should not require libgcc/libstdc++ DLLs."
}

function Build-Arm64 {
    $HostArch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    if ($HostArch -ne "Arm64") {
        Write-Host "arm64 build skipped: MSYS2 CLANGARM64 tools cannot run on this $HostArch host."
        Write-Host "Build arm64 on Windows ARM64 or in a dedicated ARM64 CI runner."
        return
    }

    Write-Host "arm64 build selected. Using MSYS2 CLANGARM64."

    $MsysRoot = "C:\msys64"
    $Bash = Join-Path $MsysRoot "usr\bin\bash.exe"
    if (!(Test-Path $Bash)) { throw "MSYS2 not found at C:\msys64" }

    $Script = Join-Path $ProjectDir ".dosty-build-clangarm64.sh"
    $ProjectMsys = Convert-ToMsysPath $ProjectDir

    Write-Utf8NoBomFile $Script @(
        '#!/usr/bin/env bash',
        'set -e',
        'PROJECT_DIR="$1"',
        'export PATH=/usr/bin:$PATH',
        'cd "$PROJECT_DIR"',
        'export MSYSTEM=CLANGARM64',
        'export PATH=/clangarm64/bin:/usr/bin:$PATH',
        'pacman -Syuu --noconfirm || true',
        'pacman -S --needed --noconfirm mingw-w64-clang-aarch64-clang mingw-w64-clang-aarch64-cmake mingw-w64-clang-aarch64-ninja mingw-w64-clang-aarch64-qt6-base mingw-w64-clang-aarch64-python',
        'rm -rf build-arm64',
        'cmake -S . -B build-arm64 -G Ninja -DCMAKE_BUILD_TYPE=MinSizeRel',
        'cmake --build build-arm64 -j'
    )

    try {
        $ScriptMsys = Convert-ToMsysPath $Script
        & $Bash $ScriptMsys $ProjectMsys
        if ($LASTEXITCODE -ne 0) { throw "MSYS2 arm64 build failed with exit code $LASTEXITCODE" }
    }
    finally {
        Remove-Item -Force $Script -ErrorAction SilentlyContinue
    }

    Write-Host "arm64 build output: build-arm64"
}

switch ($Arch) {
    "amd64" { Build-Amd64 }
    "x86" { Build-X86 }
    "arm64" { Build-Arm64 }
}
