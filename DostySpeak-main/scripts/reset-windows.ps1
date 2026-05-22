Remove-Item -Recurse -Force "$env:APPDATA\Dosty\DostySpeak" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Dosty\DostySpeak" -ErrorAction SilentlyContinue
Write-Host "Dosty Speak data removed."
