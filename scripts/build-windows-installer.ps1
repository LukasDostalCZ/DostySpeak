# Dosty Speak - Windows release artifact builder
# Examples:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-installer.ps1 -Arch amd64 -Installer -Portable
#   powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-installer.ps1 -Arch x86 -Installer -Portable

param(
    [ValidateSet("amd64", "x86")]
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
$VersionFile = Join-Path $ProjectDir "VERSION"
$AppVersion = "0.3.51"
if (Test-Path $VersionFile) { $AppVersion = (Get-Content $VersionFile -Raw).Trim() }
$AppVersionNumeric = $AppVersion
if ($AppVersionNumeric -match '^([0-9]+)\.([0-9]+)\.([0-9]+)$') { $AppVersionNumeric = "$AppVersion.0" }
$DistRoot = Join-Path $ProjectDir "dist"

if ($Arch -eq "x86") {
    $DeployName = "DostySpeak-Windows-x86"
    $SetupName = "DostySpeak-Setup-x86.exe"
    $PortableName = "DostySpeak-Portable-x86.zip"
    $DefaultInstallDir = '$PROGRAMFILES\\Dosty Speak'
} else {
    $DeployName = "DostySpeak-Windows-x86_64"
    $SetupName = "DostySpeak-Setup-x64.exe"
    $PortableName = "DostySpeak-Portable-x64.zip"
    $DefaultInstallDir = '$PROGRAMFILES64\\Dosty Speak'
}

$DeployDir = Join-Path $DistRoot $DeployName
$InstallerOut = Join-Path $DistRoot $SetupName
$PortableOut = Join-Path $DistRoot $PortableName
$NsiScript = Join-Path $ProjectDir "packaging\windows\dosty-speak.nsi"

if (!(Test-Path (Join-Path $DeployDir "dosty-speak.exe"))) {
    throw "Deployment folder not found: $DeployDir. Build/deploy this architecture first."
}

if ($Portable) {
    if (Test-Path $PortableOut) { Remove-Item -Force $PortableOut }
    Compress-Archive -Path (Join-Path $DeployDir "*") -DestinationPath $PortableOut
}

if (-not $Installer) {
    Write-Host "Portable ZIP created: $PortableOut"
    return
}

$MakensisCandidates = @(
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe"
)

$Makensis = $null
foreach ($Candidate in $MakensisCandidates) {
    if (Test-Path $Candidate) { $Makensis = $Candidate; break }
}

if ($null -eq $Makensis) {
    Write-Host "NSIS was not found. Trying to install NSIS with winget..."

    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "winget is not available. Install NSIS manually from:"
        Write-Host "  https://nsis.sourceforge.io/Download"
        exit 1
    }

    winget install --id NSIS.NSIS -e --source winget

    foreach ($Candidate in $MakensisCandidates) {
        if (Test-Path $Candidate) { $Makensis = $Candidate; break }
    }
}

if ($null -eq $Makensis) { throw "makensis.exe was still not found after NSIS installation." }

if (Test-Path $InstallerOut) { Remove-Item -Force $InstallerOut }

$LicenseFile = Join-Path $ProjectDir "packaging\windows\LICENSE-installer.txt"

Write-Host "Creating installer..."
Write-Host ("  Architecture: " + $Arch)
Write-Host ("  Source: " + $DeployDir)
Write-Host ("  Installer: " + $InstallerOut)
if ($Portable) { Write-Host ("  Portable: " + $PortableOut) }

& $Makensis `
  "/DSOURCE_DIR=$DeployDir" `
  "/DOUTPUT_EXE=$InstallerOut" `
  "/DLICENSE_FILE=$LicenseFile" `
  "/DDEFAULT_INSTALL_DIR=$DefaultInstallDir" `
  "/DAPP_VERSION=$AppVersion" `
  "/DAPP_VERSION_NUMERIC=$AppVersionNumeric" `
  $NsiScript

if (!(Test-Path $InstallerOut)) { throw "Installer was not created: $InstallerOut" }

Write-Host ""
Write-Host "Release artifacts created:"
Write-Host ("  Installer: " + $InstallerOut)
if ($Portable) { Write-Host ("  Portable ZIP: " + $PortableOut) }
