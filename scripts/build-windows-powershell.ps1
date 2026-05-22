# Dosty Speak - Windows PowerShell build helper
# Run from the project folder in normal Windows PowerShell:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-windows-powershell.ps1
#
# This script expects MSYS2 at C:\msys64 and builds Dosty Speak through MSYS2 UCRT64.
# Do NOT run pacman directly in PowerShell.

param()

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
    $OutputEncoding = New-Object System.Text.UTF8Encoding $false
    chcp 65001 | Out-Null
} catch {}

# IMPORTANT:
# Windows PowerShell 5.1 reports stderr from native tools as NativeCommandError.
# pacman prints normal warnings to stderr, so Stop would make a healthy build look failed.
$ErrorActionPreference = "Continue"

Write-Host 'Dosty Speak - Windows PowerShell build helper'
Write-Host '============================================'
Write-Host ''

$ProjectDir = (Resolve-Path '.').Path.Trim()
$MsysRoot = 'C:\msys64'
$Bash = Join-Path $MsysRoot 'usr\bin\bash.exe'

if (!(Test-Path $Bash)) {
    Write-Host ('MSYS2 was not found at ' + $MsysRoot) -ForegroundColor Red
    Write-Host 'Install MSYS2 manually from:'
    Write-Host '  https://www.msys2.org/'
    exit 1
}

function Convert-ToMsysPath {
    param([string]$WindowsPath)
    if (Test-Path $WindowsPath) {
        $Full = (Resolve-Path $WindowsPath).Path
    } else {
        $Full = [System.IO.Path]::GetFullPath($WindowsPath)
    }
    $Full = ([string]$Full).Trim()
    $Drive = $Full.Substring(0,1).ToLower()
    $Rest = $Full.Substring(2).Replace('\', '/')
    return ('/' + $Drive + $Rest).Trim()
}

function Write-Utf8NoBomFile {
    param([string]$Path, [string[]]$Lines)
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $Utf8NoBom)
}

function Run-MsysScript {
    param([string]$ScriptPath, [bool]$AllowFailure = $false, [string[]]$Arguments = @())
    $ScriptMsys = Convert-ToMsysPath $ScriptPath
    & $Bash $ScriptMsys @Arguments
    $Code = $LASTEXITCODE
    if (($Code -ne 0) -and (-not $AllowFailure)) {
        Write-Host ''
        Write-Host ('MSYS2 command failed with exit code ' + $Code) -ForegroundColor Red
        exit $Code
    }
    return $Code
}

$MsysProjectDir = Convert-ToMsysPath $ProjectDir

Write-Host 'Project directory:'
Write-Host ('  ' + $ProjectDir)
Write-Host ''
Write-Host 'MSYS2 path:'
Write-Host ('  ' + $MsysProjectDir)
Write-Host ''

$UpdateScriptWin = Join-Path $ProjectDir '.dosty-msys2-update.sh'
Write-Utf8NoBomFile $UpdateScriptWin @(
    '#!/usr/bin/env bash',
    'set +e',
    'export MSYSTEM=UCRT64',
    'export PATH=/ucrt64/bin:/usr/bin:$PATH',
    'echo "Updating MSYS2 package database / core runtime..."',
    'pacman -Syuu --noconfirm',
    'exit 0'
)

try {
    $UpdateCode = Run-MsysScript -ScriptPath $UpdateScriptWin -AllowFailure $true
    if ($UpdateCode -ne 0) {
        Write-Host ''
        Write-Host 'MSYS2 update ended with a non-zero code. This can be normal after msys2-runtime/pacman upgrade.' -ForegroundColor Yellow
        Write-Host 'Continuing with a fresh MSYS2 process...'
        Write-Host ''
        Start-Sleep -Seconds 3
    }
} finally {
    Remove-Item -Force $UpdateScriptWin -ErrorAction SilentlyContinue
}

$BuildScriptWin = Join-Path $ProjectDir '.dosty-build-msys2.sh'
Write-Utf8NoBomFile $BuildScriptWin @(
    '#!/usr/bin/env bash',
    'set -e',
    'export MSYSTEM=UCRT64',
    'export PATH=/ucrt64/bin:/usr/bin:$PATH',
    '',
    'PROJECT_DIR="$1"',
    'cd "$PROJECT_DIR"',
    '',
    'echo "Current directory:"',
    'pwd',
    '',
    'echo "Installing build dependencies..."',
    'pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-qt6-base mingw-w64-ucrt-x86_64-python',
    '',
    'echo "Removing old build folder..."',
    'rm -rf build',
    '',
    'echo "Configuring CMake..."',
    'cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release',
    '',
    'echo "Building Dosty Speak..."',
    'cmake --build build -j',
    '',
    'echo "Build finished."',
    'echo "Executable:"',
    'echo "$PROJECT_DIR/build/dosty-speak.exe"'
)

try {
    Run-MsysScript -ScriptPath $BuildScriptWin -AllowFailure $false -Arguments @($MsysProjectDir) | Out-Null
} finally {
    Remove-Item -Force $BuildScriptWin -ErrorAction SilentlyContinue
}

$Exe = Join-Path $ProjectDir 'build\dosty-speak.exe'
if (!(Test-Path $Exe)) {
    Write-Host ('Build finished but executable was not found: ' + $Exe) -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host 'Build finished.' -ForegroundColor Green
Write-Host 'Creating runnable Windows deployment folder...'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectDir 'scripts\deploy-windows-powershell.ps1')
$DeployCode = $LASTEXITCODE
if ($DeployCode -ne 0) { exit $DeployCode }

Write-Host ''
Write-Host 'Run:'
Write-Host '  .\dist\DostySpeak-Windows-x86_64\dosty-speak.exe'
Write-Host ''
Write-Host 'Or double-click:'
Write-Host '  dist\DostySpeak-Windows-x86_64\run-dosty-speak.cmd'
Write-Host ''
exit 0
