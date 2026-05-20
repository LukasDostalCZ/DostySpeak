# Run deployed Dosty Speak on Windows
$Exe = ".\dist\DostySpeak-Windows-x86_64\dosty-speak.exe"

if (!(Test-Path $Exe)) {
    Write-Host "Deployed executable not found."
    Write-Host "Create it first:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\deploy-windows-powershell.ps1"
    exit 1
}

& $Exe
