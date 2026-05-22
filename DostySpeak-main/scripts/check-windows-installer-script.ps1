$ErrorActionPreference = "Stop"

$NsiScript = Join-Path (Resolve-Path ".").Path "packaging\windows\dosty-speak.nsi"

$MakensisCandidates = @(
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "makensis.exe"
)

$Makensis = $null
foreach ($candidate in $MakensisCandidates) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
        $Makensis = $cmd.Source
        break
    }
}

if (-not $Makensis) {
    Write-Host "makensis not found. Install NSIS first."
    exit 1
}

$DummySource = Join-Path $env:TEMP "dosty-speak-nsis-check"
New-Item -ItemType Directory -Force -Path $DummySource | Out-Null
"dummy" | Set-Content -Encoding ASCII (Join-Path $DummySource "dosty-speak.exe")
"license" | Set-Content -Encoding ASCII (Join-Path $DummySource "LICENSE.txt")

$Out = Join-Path $env:TEMP "DostySpeak-NSIS-Check.exe"
$License = Join-Path (Resolve-Path ".").Path "packaging\windows\LICENSE-installer.txt"

& $Makensis `
  "/DSOURCE_DIR=$DummySource" `
  "/DOUTPUT_EXE=$Out" `
  "/DLICENSE_FILE=$License" `
  "/DDEFAULT_INSTALL_DIR=$PROGRAMFILES64\Dosty Speak" `
  $NsiScript

if (Test-Path $Out) {
    Remove-Item -Force $Out
}

Write-Host "NSIS script check passed."
