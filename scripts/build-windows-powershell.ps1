# Dosty Speak - Windows PowerShell build helper
# Run from the project folder in normal Windows PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-powershell.ps1
#
# This script installs MSYS2 via winget if needed, then builds Dosty Speak
# through MSYS2 UCRT64. Do NOT run pacman directly in PowerShell.

# Keep Windows PowerShell console output readable with UTF-8 text.
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 | Out-Null
} catch {
    # Non-fatal on older shells.
}

$ErrorActionPreference = "Stop"

Write-Host 'Dosty Speak - Windows PowerShell build helper'
Write-Host '============================================'
Write-Host ''

$ProjectDir = (Resolve-Path '.').Path.Trim()
$MsysRoot = 'C:\msys64'
$Bash = Join-Path $MsysRoot 'usr\bin\bash.exe'

if (!(Test-Path $Bash)) {
    Write-Host ('MSYS2 was not found at ' + $MsysRoot)
    Write-Host 'Trying to install MSYS2 with winget...'

    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host ''
        Write-Host 'winget is not available on this system.'
        Write-Host 'Install MSYS2 manually from:'
        Write-Host '  https://www.msys2.org/'
        Write-Host ''
        Write-Host 'Then open MSYS2 UCRT64 and run the commands from README.md.'
        exit 1
    }

    winget install --id MSYS2.MSYS2 -e --source winget

    if (!(Test-Path $Bash)) {
        Write-Host ''
        Write-Host 'MSYS2 installation finished, but bash.exe was not found at:'
        Write-Host ('  ' + $Bash)
        Write-Host 'Close this PowerShell window, open it again, and re-run this script.'
        exit 1
    }
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

function Write-BashScript {
    param(
        [string]$ScriptPath,
        [string[]]$Lines
    )

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($ScriptPath, $Lines, $Utf8NoBom)
}

function Run-MsysScript {
    param(
        [string]$ScriptPath,
        [bool]$AllowFailure = $false
    )

    $ScriptMsys = Convert-ToMsysPath $ScriptPath
    & $Bash $ScriptMsys
    $Code = $LASTEXITCODE

    if (($Code -ne 0) -and (-not $AllowFailure)) {
        throw ('MSYS2 command failed with exit code ' + $Code)
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

# MSYS2 sometimes updates msys2-runtime/pacman and intentionally terminates
# all MSYS2 processes. That is normal. We therefore run update separately,
# allow a non-zero exit code here, wait a moment, and then start a fresh
# MSYS2 process for the actual dependency install/build.
$UpdateScriptWin = Join-Path $ProjectDir '.dosty-msys2-update.sh'
$UpdateLines = @(
    '#!/usr/bin/env bash',
    'export MSYSTEM=UCRT64',
    'export PATH=/ucrt64/bin:/usr/bin:$PATH',
    'echo "Updating MSYS2 package database / core runtime..."',
    'pacman -Syuu --noconfirm'
)

Write-BashScript -ScriptPath $UpdateScriptWin -Lines $UpdateLines

try {
    $UpdateCode = Run-MsysScript -ScriptPath $UpdateScriptWin -AllowFailure $true
    if ($UpdateCode -ne 0) {
        Write-Host ''
        Write-Host 'MSYS2 update ended with a non-zero code. This is often normal when msys2-runtime or pacman was upgraded.'
        Write-Host 'Continuing with a fresh MSYS2 process...'
        Write-Host ''
        Start-Sleep -Seconds 3
    }
}
finally {
    Remove-Item -Force $UpdateScriptWin -ErrorAction SilentlyContinue
}

$BuildScriptWin = Join-Path $ProjectDir '.dosty-build-msys2.sh'
$BuildLines = @(
    '#!/usr/bin/env bash',
    'set -e',
    'export MSYSTEM=UCRT64',
    'export PATH=/ucrt64/bin:/usr/bin:$PATH',
    '',
    'SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"',
    'cd "$SCRIPT_DIR"',
    '',
    'echo "Current directory:"',
    'pwd',
    '',
    'echo "Installing build dependencies..."',
    'pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-qt6-base mingw-w64-ucrt-x86_64-python',
    '',
    'echo "Building Dosty Speak..."',
    'rm -rf build',
    'cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release',
    'cmake --build build -j',
    '',
    'echo "Build finished."',
    'echo "Executable:"',
    'echo "$SCRIPT_DIR/build/dosty-speak.exe"'
)

Write-BashScript -ScriptPath $BuildScriptWin -Lines $BuildLines

try {
    Run-MsysScript -ScriptPath $BuildScriptWin -AllowFailure $false | Out-Null
}
finally {
    Remove-Item -Force $BuildScriptWin -ErrorAction SilentlyContinue
}

$Exe = Join-Path $ProjectDir 'build\dosty-speak.exe'
if (!(Test-Path $Exe)) {
    throw ('Build finished but executable was not found: ' + $Exe)
}

Write-Host ''
Write-Host 'Build finished.'
Write-Host 'Creating runnable Windows deployment folder...'
& powershell -ExecutionPolicy Bypass -File .\scripts\deploy-windows-powershell.ps1
Write-Host ''
Write-Host 'Run:'
Write-Host '  .\dist\DostySpeak-Windows-x86_64\dosty-speak.exe'
Write-Host ''
Write-Host 'Or double-click:'
Write-Host '  dist\DostySpeak-Windows-x86_64\run-dosty-speak.cmd'


Write-Host ''
