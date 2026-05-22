# Dosty Speak - Windows terminal builder
# Safe for Windows PowerShell 5.1 on Windows 10 LTSC 2019 and Windows 11.
# Run from the project root:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
    $OutputEncoding = New-Object System.Text.UTF8Encoding $false
} catch {}

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

$VersionFile = Join-Path $Root "VERSION"
if (Test-Path $VersionFile) { $Version = (Get-Content $VersionFile -Raw).Trim() } else { $Version = "dev" }

$LogDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir ("dosty-speak-" + $Version + "-windows-build-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
New-Item -ItemType File -Force -Path $LogFile | Out-Null

$options = @(
    [pscustomobject]@{ Key="deps";      Label="Install/check Windows dependencies"; Selected=$true;  Help="Checks MSYS2, CMake, Ninja, Qt desktop tools and Android SDK tools." },
    [pscustomobject]@{ Key="win64";     Label="Build Windows desktop 64-bit";      Selected=$true;  Help="Builds the normal Windows desktop app." },
    [pscustomobject]@{ Key="installer"; Label="Create Windows installer EXE";      Selected=$true;  Help="Creates installer EXE when NSIS is available." },
    [pscustomobject]@{ Key="portable";  Label="Create portable ZIP";              Selected=$true;  Help="Creates portable ZIP in the dist folder." },
    [pscustomobject]@{ Key="android";   Label="Build Android APK on Windows";      Selected=$false; Help="Installs/checks Android command-line tools, SDK platform, build-tools and NDK. Qt Android kit must exist." },
    [pscustomobject]@{ Key="win32";     Label="Build legacy 32-bit Win32";        Selected=$false; Help="Optional legacy SAPI-only build for older Windows." }
)

$cursor = 0

function SelectedText([bool]$value) {
    if ($value) { return "x" }
    return " "
}

function Draw-Header {
    Clear-Host
    Write-Host "+------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                  Dosty Speak Windows builder                    |" -ForegroundColor Cyan
    Write-Host "+------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("Version: " + $Version) -ForegroundColor White
    Write-Host ("Log:     " + $LogFile) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Controls: Up/Down move | Space toggle | Enter continue | A all/none | Q quit" -ForegroundColor Yellow
    Write-Host "Numbers 1-6 also toggle items." -ForegroundColor DarkGray
    Write-Host ""
}

function DrawMenu {
    Draw-Header
    for ($i = 0; $i -lt $options.Count; $i++) {
        $mark = SelectedText $options[$i].Selected
        $line = (" {0}) [{1}] {2}" -f ($i + 1), $mark, $options[$i].Label)
        if ($i -eq $cursor) {
            Write-Host (" >>" + $line) -ForegroundColor Black -BackgroundColor Gray
        } else {
            Write-Host ("   " + $line) -ForegroundColor White
        }
    }
    Write-Host ""
    Write-Host "Selected item:" -ForegroundColor Yellow
    Write-Host ("  " + $options[$cursor].Help) -ForegroundColor Gray
    Write-Host ""
    Write-Host "Tip: Android SDK/NDK can be installed by this builder when sdkmanager is available." -ForegroundColor DarkGray
    Write-Host "Tip: Android build now tries to install Qt kits automatically through aqtinstall, then falls back to Qt Online Installer." -ForegroundColor DarkGray
}

function Toggle-ByNumber([int]$number) {
    $idx = $number - 1
    if ($idx -ge 0 -and $idx -lt $options.Count) {
        $options[$idx].Selected = -not $options[$idx].Selected
        $script:cursor = $idx
    }
}

:MenuLoop while ($true) {
    DrawMenu
    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
        "UpArrow"   { $cursor--; if ($cursor -lt 0) { $cursor = $options.Count - 1 } }
        "DownArrow" { $cursor++; if ($cursor -ge $options.Count) { $cursor = 0 } }
        "Spacebar"  { $options[$cursor].Selected = -not $options[$cursor].Selected }
        "A" {
            $anyOff = $false
            foreach ($o in $options) { if (-not $o.Selected) { $anyOff = $true } }
            foreach ($o in $options) { $o.Selected = $anyOff }
        }
        "Q" { exit 0 }
        "Enter" { break MenuLoop }
        "D1" { Toggle-ByNumber 1 }
        "D2" { Toggle-ByNumber 2 }
        "D3" { Toggle-ByNumber 3 }
        "D4" { Toggle-ByNumber 4 }
        "D5" { Toggle-ByNumber 5 }
        "D6" { Toggle-ByNumber 6 }
        "NumPad1" { Toggle-ByNumber 1 }
        "NumPad2" { Toggle-ByNumber 2 }
        "NumPad3" { Toggle-ByNumber 3 }
        "NumPad4" { Toggle-ByNumber 4 }
        "NumPad5" { Toggle-ByNumber 5 }
        "NumPad6" { Toggle-ByNumber 6 }
    }
}

function IsSelected([string]$Key) {
    foreach ($o in $options) { if ($o.Key -eq $Key) { return [bool]$o.Selected } }
    return $false
}

function Write-LogLine([string]$Text) {
    $Text | Tee-Object -FilePath $LogFile -Append
}

function Run-Step([string]$Title, [scriptblock]$Block) {
    Clear-Host
    Write-Host "+------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                         Dosty Speak build                       |" -ForegroundColor Cyan
    Write-Host "+------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("Version: " + $Version)
    Write-Host ("Step:    " + $Title)
    Write-Host ("Log:     " + $LogFile)
    Write-Host ""
    Write-Host "Real output is shown here. If a tool asks for confirmation or password, type directly in this window." -ForegroundColor Yellow
    Write-Host ""

    Write-LogLine ""
    Write-LogLine "============================================================"
    Write-LogLine $Title
    Write-LogLine ("Started: " + (Get-Date))
    Write-LogLine "============================================================"

    $global:LASTEXITCODE = 0
    $oldEA = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Block 2>&1 | ForEach-Object {
            $line = $_.ToString()
            Add-Content -LiteralPath $LogFile -Value $line
            if ($line -match "(?i)^warning| warning:|was not found|not found|manual step|required") {
                Write-Host $line -ForegroundColor Yellow
            } elseif ($line -match "(?i)^error:|fatal|failed|exception|cannot|throw") {
                Write-Host $line -ForegroundColor Red
            } else {
                Write-Host $line
            }
        }
        $code = $global:LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
    } catch {
        $line = $_.ToString()
        Add-Content -LiteralPath $LogFile -Value $line
        Write-Host $line -ForegroundColor Red
        $code = 1
    }
    $ErrorActionPreference = $oldEA

    Write-LogLine ("Finished: " + (Get-Date))
    Write-LogLine ("Exit code: " + $code)

    if ($code -ne 0) {
        Write-Host ""
        Write-Host "Step failed." -ForegroundColor Red
        Write-Host "Log saved here:" -ForegroundColor Yellow
        Write-Host ("  " + $LogFile)
        Write-Host ""
        $answer = Read-Host "Press Enter to continue, R retry, Q quit"
        if ($answer -match "^[Rr]$") { Run-Step $Title $Block }
        if ($answer -match "^[Qq]$") { exit 1 }
    } else {
        Write-Host ""
        Write-Host "Step finished successfully." -ForegroundColor Green
        Start-Sleep -Milliseconds 500
    }
}

Clear-Host
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "======="
foreach ($o in $options) {
    $mark = SelectedText $o.Selected
    Write-Host ("[{0}] {1}" -f $mark, $o.Label)
}
Write-Host ""
$go = Read-Host "Start build? [Y/n]"
if ($go -match "^[Nn]$") { exit 0 }

if (IsSelected "deps") {
    Run-Step "Install/check Windows dependencies" {
        Write-Host ("PowerShell: " + $PSVersionTable.PSVersion)
        Write-Host ("Project:    " + $Root)
        Write-Host ("Version:    " + $Version)
        Write-Host ""
        if (Get-Command cmake.exe -ErrorAction SilentlyContinue) { cmake --version | Select-Object -First 1 } else { Write-Host "cmake.exe not found yet" -ForegroundColor Yellow }
        if (Get-Command ninja.exe -ErrorAction SilentlyContinue) { Write-Host ("ninja: " + (ninja --version)) } else { Write-Host "ninja.exe not found yet" -ForegroundColor Yellow }
        if (Test-Path "C:\msys64\usr\bin\bash.exe") { Write-Host "MSYS2 found at C:\msys64" -ForegroundColor Green } else { Write-Host "MSYS2 not found at C:\msys64" -ForegroundColor Yellow }
        if (Get-Command winget.exe -ErrorAction SilentlyContinue) { Write-Host "winget found" -ForegroundColor Green } else { Write-Host "winget not found, manual installers may be needed" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "Android tool check:" -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\build-android-apk-windows.ps1" -SetupOnly
    }
}

if (IsSelected "win64") {
    Run-Step "Build Windows desktop 64-bit" {
        $buildArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\scripts\build-windows-release.ps1", "-Arch", "amd64")
        if (IsSelected "installer") { $buildArgs += "-Installer" }
        if (IsSelected "portable") { $buildArgs += "-Portable" }
        & powershell.exe @buildArgs
    }
}

if (IsSelected "win32") {
    Run-Step "Build legacy 32-bit Win32" {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\build-windows-release.ps1" -Arch x86 -Portable
    }
}

if (IsSelected "android") {
    Run-Step "Build Android APK on Windows" {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\build-android-apk-windows.ps1"
    }
}

Clear-Host
Write-Host "Done." -ForegroundColor Green
Write-Host "Log saved to:"
Write-Host ("  " + $LogFile)
Write-Host ""
Write-Host "Build outputs are usually in:"
Write-Host "  dist"
Write-Host "  dist\android"
Write-Host ""
Write-Host "You can send me the log above if anything still fails."
