# Dosty Speak — Windows installer for MSYS2 UCRT64
# Run inside MSYS2 UCRT64 shell:
#   powershell -ExecutionPolicy Bypass -File scripts/install-windows-msys2.ps1

Write-Host "Dosty Speak — Windows/MSYS2 installer"
Write-Host "====================================="

bash -lc "pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-qt6-base mingw-w64-ucrt-x86_64-python"

bash -lc "cmake -S . -B build -G 'MinGW Makefiles' -DCMAKE_BUILD_TYPE=Release"
bash -lc "cmake --build build -j"

$installDir = "$env:LOCALAPPDATA\DostySpeak"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item -Force "build\dosty-speak.exe" "$installDir\dosty-speak.exe"
Copy-Item -Recurse -Force "build\resources" "$installDir\resources"

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "Dosty Speak.lnk"
$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$installDir\dosty-speak.exe"
$shortcut.WorkingDirectory = $installDir
$shortcut.Save()

Write-Host ""
Write-Host "Installed to: $installDir"
Write-Host "Desktop shortcut created: $shortcutPath"
Write-Host "You may still need to run windeployqt for a fully portable folder:"
Write-Host "  windeployqt $installDir\dosty-speak.exe"
