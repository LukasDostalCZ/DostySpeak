param(
    [Parameter(Mandatory=$true)]
    [string]$TargetRepo
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceRoot = Resolve-Path (Join-Path $scriptDir "..")
$targetRoot = Resolve-Path $TargetRepo

if ($sourceRoot.Path.TrimEnd('\') -ieq $targetRoot.Path.TrimEnd('\')) {
    Write-Host "Refusing to sync onto the same directory." -ForegroundColor Red
    Write-Host "Unzip this package into a temporary folder, then pass your real git checkout as the argument."
    exit 1
}

$gitDir = Join-Path $targetRoot ".git"
if (-not (Test-Path $gitDir)) {
    Write-Host "Target does not contain .git: $targetRoot" -ForegroundColor Red
    Write-Host "Use your existing git checkout as the target."
    exit 1
}

$version = "unknown"
$versionFile = Join-Path $sourceRoot "VERSION"
if (Test-Path $versionFile) {
    $version = (Get-Content $versionFile -Raw).Trim()
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path (Split-Path -Parent $targetRoot) "dosty-speak-backup-before-sync-$version-$stamp.zip"

Write-Host "Dosty Speak - sync package to git checkout" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Source: $sourceRoot"
Write-Host "Target: $targetRoot"
Write-Host "Version: $version"
Write-Host ""
Write-Host "Creating safety backup without .git:" -ForegroundColor Yellow
Write-Host "  $backup"

$tempBackup = Join-Path $env:TEMP "dosty-speak-backup-$stamp"
if (Test-Path $tempBackup) { Remove-Item $tempBackup -Recurse -Force }
New-Item -ItemType Directory -Path $tempBackup | Out-Null

Get-ChildItem -LiteralPath $targetRoot -Force | Where-Object { $_.Name -ne ".git" } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $tempBackup -Recurse -Force
}
Compress-Archive -Path (Join-Path $tempBackup "*") -DestinationPath $backup -Force
Remove-Item $tempBackup -Recurse -Force

Write-Host ""
Write-Host "Replacing working tree while preserving .git..." -ForegroundColor Yellow

Get-ChildItem -LiteralPath $targetRoot -Force | Where-Object { $_.Name -ne ".git" } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
}

$robocopyArgs = @(
    $sourceRoot.Path,
    $targetRoot.Path,
    "/MIR",
    "/XD", ".git", "build-*", "dist", "logs",
    "/XF", "*.user",
    "/R:2",
    "/W:1"
)
& robocopy @robocopyArgs | Out-Host
$rc = $LASTEXITCODE
if ($rc -gt 7) {
    throw "Robocopy failed with exit code $rc"
}

Write-Host ""
Write-Host "Done. Git status in target:" -ForegroundColor Green
Set-Location $targetRoot
& git status --short

Write-Host ""
Write-Host "Next recommended commands:" -ForegroundColor Cyan
Write-Host "  git diff --stat"
Write-Host "  git diff"
Write-Host "  git add -A"
Write-Host "  git commit -m \"Update Dosty Speak to $version\""
Write-Host "  git push"
