# Dosty Speak - check Windows x86 legacy build support
# Run:
#   powershell -ExecutionPolicy Bypass -File .\scripts\check-windows-x86-support.ps1
#
# x86 now uses the pure Win32 legacy frontend. It only needs MINGW32 GCC.

$ErrorActionPreference = "Stop"

$MsysRoot = "C:\msys64"
$Bash = Join-Path $MsysRoot "usr\bin\bash.exe"

if (!(Test-Path $Bash)) {
    Write-Host "MSYS2 not found at C:\msys64"
    exit 1
}

$ProjectDir = (Resolve-Path ".").Path
$Script = Join-Path $ProjectDir ".dosty-check-x86.sh"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllLines($Script, @(
    '#!/usr/bin/env bash',
    'set -e',
    'export PATH=/usr/bin:$PATH',
    'echo "Checking MINGW32 GCC for pure Win32 x86 build..."',
    'pacman -Sl mingw32 2>/dev/null | grep -E "mingw-w64-i686-(gcc|gcc-libs)" || true',
    'if pacman -Sl mingw32 2>/dev/null | grep -q "mingw-w64-i686-gcc"; then',
    '  echo "OK: mingw-w64-i686-gcc is available."',
    '  exit 0',
    'fi',
    'echo "NOT_AVAILABLE: mingw-w64-i686-gcc was not found."',
    'exit 2'
), $Utf8NoBom)

function Convert-ToMsysPath([string]$WindowsPath) {
    $Full = [System.IO.Path]::GetFullPath($WindowsPath)
    $Drive = $Full.Substring(0,1).ToLower()
    $Rest = $Full.Substring(2).Replace("\","/")
    return "/" + $Drive + $Rest
}

try {
    & $Bash (Convert-ToMsysPath $Script)
    $code = $LASTEXITCODE
}
finally {
    Remove-Item -Force $Script -ErrorAction SilentlyContinue
}

if ($code -eq 0) {
    Write-Host ""
    Write-Host "Windows x86 pure Win32 legacy build should be possible."
    exit 0
}

Write-Host ""
Write-Host "Windows x86 build is not available because MINGW32 GCC is missing."
exit 2
