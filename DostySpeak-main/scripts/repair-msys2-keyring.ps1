# Dosty Speak - repair MSYS2 keyring/database
# Fixes common Windows/MSYS2 errors:
#   signature ... is unknown trust
#   invalid or corrupted database (PGP signature)
#
# Run from project folder:
#   powershell -ExecutionPolicy Bypass -File .\scripts\repair-msys2-keyring.ps1

$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 | Out-Null
} catch {}

$MsysRoot = "C:\msys64"
$Bash = Join-Path $MsysRoot "usr\bin\bash.exe"

if (!(Test-Path $Bash)) {
    Write-Host "MSYS2 was not found at C:\msys64"
    Write-Host "Install MSYS2 manually from:"
    Write-Host "  https://www.msys2.org/"
    exit 1
}

$Script = Join-Path $env:TEMP ("dosty-repair-msys2-" + [guid]::NewGuid().ToString() + ".sh")
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllLines($Script, @(
    '#!/usr/bin/env bash',
    'set -e',
    'export PATH=/usr/bin:$PATH',
    'echo "Repairing MSYS2 keyring and package databases..."',
    'echo',
    'echo "Killing possible stale pacman/gpg processes..."',
    'taskkill.exe /F /IM gpg-agent.exe >/dev/null 2>&1 || true',
    'taskkill.exe /F /IM pacman.exe >/dev/null 2>&1 || true',
    'echo',
    'echo "Removing stale sync databases..."',
    'rm -f /var/lib/pacman/sync/*.db /var/lib/pacman/sync/*.db.sig',
    'rm -f /var/lib/pacman/sync/*.files /var/lib/pacman/sync/*.files.sig',
    'echo',
    'echo "Refreshing MSYS2 keyring..."',
    'pacman-key --init || true',
    'pacman-key --populate msys2 || true',
    'pacman -Sy --noconfirm msys2-keyring || true',
    'pacman-key --populate msys2 || true',
    'echo',
    'echo "Synchronizing package databases..."',
    'pacman -Syy --noconfirm',
    'echo',
    'echo "MSYS2 keyring/database repair finished."'
), $Utf8NoBom)

function Convert-ToMsysPath([string]$WindowsPath) {
    $Full = [System.IO.Path]::GetFullPath($WindowsPath)
    $Drive = $Full.Substring(0,1).ToLower()
    $Rest = $Full.Substring(2).Replace("\","/")
    return "/" + $Drive + $Rest
}

try {
    & $Bash (Convert-ToMsysPath $Script)
    if ($LASTEXITCODE -ne 0) {
        throw "MSYS2 repair failed with exit code $LASTEXITCODE"
    }
}
finally {
    Remove-Item -Force $Script -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Repair done. Run the Windows release builder again."
