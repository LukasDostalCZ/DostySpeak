# Dosty Speak - clean Windows build outputs
$ErrorActionPreference = "Stop"

$ProjectDir = (Resolve-Path ".").Path

$paths = @(
    "build",
    "build-x86",
    "build-x86-win32",
    "build-x86-legacy",
    "build-arm64",
    "dist"
)

foreach ($p in $paths) {
    $full = Join-Path $ProjectDir $p
    if (Test-Path $full) {
        Write-Host "Removing $full"
        Remove-Item -Recurse -Force $full
    }
}

Get-ChildItem -Path $ProjectDir -Filter ".dosty-build-*.sh" -Force -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $ProjectDir -Filter ".dosty-check-*.sh" -Force -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "Windows build outputs cleaned."
