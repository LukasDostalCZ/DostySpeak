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
$LatestLogFile = Join-Path $LogDir "latest-windows-build.log"
New-Item -ItemType File -Force -Path $LogFile | Out-Null
New-Item -ItemType File -Force -Path $LatestLogFile | Out-Null
Clear-Content -LiteralPath $LogFile -ErrorAction SilentlyContinue
Clear-Content -LiteralPath $LatestLogFile -ErrorAction SilentlyContinue

function New-Option([string]$Key, [string]$Group, [string]$Label, [bool]$Selected, [string]$Help) {
    return [pscustomobject]@{
        Key = $Key
        Group = $Group
        Label = $Label
        Selected = $Selected
        Help = $Help
    }
}

$options = @(
    (New-Option "deps"      "Setup"             "Install/check Windows dependencies" $true  "Checks MSYS2, CMake, Ninja, Qt desktop tools and Android SDK tools."),
    (New-Option "win64"     "Windows desktop"   "Build Windows desktop 64-bit"      $true  "Builds the normal Windows desktop app."),
    (New-Option "installer" "Windows desktop"   "Create Windows installer EXE"      $true  "Creates installer EXE when NSIS is available."),
    (New-Option "portable"  "Windows desktop"   "Create portable ZIP"              $true  "Creates portable ZIP in the dist folder."),
    (New-Option "android"   "Android"           "Build Android APK on Windows"      $false "Installs/checks Android command-line tools, SDK platform, build-tools and NDK. Qt Android kit must exist."),
    (New-Option "win32"     "Legacy"            "Build legacy 32-bit Win32"         $false "Optional SAPI-only build for older Windows.")
)

$presets = @(
    [pscustomobject]@{ Hotkey = "1"; Label = "Desktop release"; Keys = @("deps", "win64", "installer", "portable") },
    [pscustomobject]@{ Hotkey = "2"; Label = "Portable only";   Keys = @("deps", "win64", "portable") },
    [pscustomobject]@{ Hotkey = "3"; Label = "Android debug";   Keys = @("deps", "android") },
    [pscustomobject]@{ Hotkey = "4"; Label = "Everything";      Keys = @("deps", "win64", "installer", "portable", "android", "win32") }
)

$cursor = 0
$scroll = 0
$message = "Presets: 1 desktop, 2 portable, 3 android, 4 everything."

function Get-ConsoleWidth {
    try {
        $w = [Console]::WindowWidth
        if ($w -lt 20) { return 100 }
        return $w
    } catch {
        return 100
    }
}

function Get-ConsoleHeight {
    try {
        $h = [Console]::WindowHeight
        if ($h -lt 10) { return 30 }
        return $h
    } catch {
        return 30
    }
}

function Fit-Text([string]$Text, [int]$Width) {
    if ($null -eq $Text) { $Text = "" }
    if ($Width -le 0) { return "" }
    if ($Text.Length -le $Width) { return $Text }
    if ($Width -le 1) { return $Text.Substring(0, 1) }
    return $Text.Substring(0, $Width - 1) + "."
}

function Pad-Text([string]$Text, [int]$Width) {
    $t = Fit-Text $Text $Width
    if ($t.Length -lt $Width) { return $t + (" " * ($Width - $t.Length)) }
    return $t
}

function Write-Rule([int]$Width, [string]$Title) {
    $inner = [Math]::Max(10, $Width - 2)
    if ([string]::IsNullOrWhiteSpace($Title)) {
        Write-Host ("+" + ("-" * $inner) + "+") -ForegroundColor DarkCyan
        return
    }
    $label = " " + (Fit-Text $Title ([Math]::Max(1, $inner - 4))) + " "
    $left = [Math]::Max(1, [Math]::Floor(($inner - $label.Length) / 2))
    $right = [Math]::Max(1, $inner - $label.Length - $left)
    Write-Host ("+" + ("-" * $left) + $label + ("-" * $right) + "+") -ForegroundColor DarkCyan
}

function Write-BoxLine([string]$Text, [int]$Width, [ConsoleColor]$Color) {
    $inner = [Math]::Max(1, $Width - 4)
    Write-Host ("| " + (Pad-Text $Text $inner) + " |") -ForegroundColor $Color
}

function Build-Rows {
    $rows = @()
    $lastGroup = ""
    for ($i = 0; $i -lt $options.Count; $i++) {
        if ($options[$i].Group -ne $lastGroup) {
            $rows += [pscustomobject]@{ Type = "group"; Text = $options[$i].Group; Index = -1 }
            $lastGroup = $options[$i].Group
        }
        $rows += [pscustomobject]@{ Type = "option"; Text = $options[$i].Label; Index = $i }
    }
    return $rows
}

function SelectedText([bool]$value) {
    if ($value) { return "x" }
    return " "
}

function SelectedCount {
    $count = 0
    foreach ($o in $options) { if ($o.Selected) { $count++ } }
    return $count
}

function Set-Preset([string]$Hotkey) {
    foreach ($preset in $presets) {
        if ($preset.Hotkey -eq $Hotkey) {
            foreach ($o in $options) { $o.Selected = ($preset.Keys -contains $o.Key) }
            for ($i = 0; $i -lt $options.Count; $i++) {
                if ($preset.Keys -contains $options[$i].Key) {
                    $script:cursor = $i
                    break
                }
            }
            $script:message = "Preset selected: " + $preset.Label
            return
        }
    }
}

function Open-LogFolder {
    try {
        Start-Process explorer.exe -ArgumentList @($LogDir) | Out-Null
        $script:message = "Opened logs folder."
    } catch {
        $script:message = "Could not open logs folder."
    }
}

function DrawMenu {
    Clear-Host
    $width = Get-ConsoleWidth
    $height = Get-ConsoleHeight

    if ($width -lt 76 -or $height -lt 22) {
        Write-Host "Dosty Speak Windows builder" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "The terminal is too small. Please resize it to at least 76 x 22." -ForegroundColor Yellow
        Write-Host "Press Q to quit or any other key to redraw."
        return
    }

    $boxWidth = [Math]::Min($width - 2, 112)
    $listWidth = [Math]::Min(58, [Math]::Max(44, [Math]::Floor($boxWidth * 0.55)))
    $detailWidth = $boxWidth - $listWidth - 5
    $visibleRows = [Math]::Max(8, $height - 15)
    $rows = Build-Rows

    $cursorRow = 0
    for ($r = 0; $r -lt $rows.Count; $r++) {
        if ($rows[$r].Type -eq "option" -and $rows[$r].Index -eq $cursor) {
            $cursorRow = $r
            break
        }
    }
    if ($cursorRow -lt $script:scroll) { $script:scroll = $cursorRow }
    if ($cursorRow -ge ($script:scroll + $visibleRows)) { $script:scroll = $cursorRow - $visibleRows + 1 }
    $maxScroll = [Math]::Max(0, $rows.Count - $visibleRows)
    if ($script:scroll -gt $maxScroll) { $script:scroll = $maxScroll }
    if ($script:scroll -lt 0) { $script:scroll = 0 }

    Write-Rule $boxWidth "Dosty Speak Windows builder"
    Write-BoxLine ("Version: " + $Version + "    Selected: " + (SelectedCount)) $boxWidth White
    Write-BoxLine ("Log: " + $LogFile) $boxWidth DarkGray
    Write-BoxLine "Up/Down or j/k: move   Space: toggle   Enter: build   A: all/none   N: none   L: logs   Q: quit" $boxWidth Yellow
    Write-Rule $boxWidth ""
    Write-Host ""

    $leftTitle = Pad-Text " Build options " ($listWidth - 2)
    $rightTitle = Pad-Text " Detail " ($detailWidth - 2)
    Write-Host ("+" + $leftTitle + "+   +" + $rightTitle + "+") -ForegroundColor DarkCyan

    $shown = $rows[$script:scroll..([Math]::Min($rows.Count - 1, $script:scroll + $visibleRows - 1))]
    $current = $options[$cursor]
    $detailLines = @(
        $current.Label,
        ("Group: " + $current.Group),
        ("Selected: " + $(if ($current.Selected) { "yes" } else { "no" })),
        "",
        $current.Help,
        "",
        "Presets:",
        "1 Desktop release",
        "2 Portable only",
        "3 Android debug",
        "4 Everything"
    )

    for ($i = 0; $i -lt $visibleRows; $i++) {
        $left = ""
        $leftColor = [ConsoleColor]::White
        if ($i -lt $shown.Count) {
            $row = $shown[$i]
            if ($row.Type -eq "group") {
                $left = "-- " + $row.Text
                $leftColor = [ConsoleColor]::Magenta
            } else {
                $opt = $options[$row.Index]
                $prefix = " "
                if ($row.Index -eq $cursor) { $prefix = ">" }
                $left = ("{0} [{1}] {2}" -f $prefix, (SelectedText $opt.Selected), $opt.Label)
                if ($row.Index -eq $cursor) { $leftColor = [ConsoleColor]::Black }
            }
        }

        $right = ""
        $rightColor = [ConsoleColor]::Gray
        if ($i -lt $detailLines.Count) {
            $right = $detailLines[$i]
            if ($i -eq 0) { $rightColor = [ConsoleColor]::Cyan }
            if ($i -eq 2) {
                if ($current.Selected) { $rightColor = [ConsoleColor]::Green } else { $rightColor = [ConsoleColor]::Red }
            }
        }

        $leftText = "| " + (Pad-Text $left ($listWidth - 4)) + " |"
        $rightText = "| " + (Pad-Text $right ($detailWidth - 4)) + " |"
        if ($i -lt $shown.Count -and $shown[$i].Type -eq "option" -and $shown[$i].Index -eq $cursor) {
            Write-Host $leftText -ForegroundColor Black -BackgroundColor Gray -NoNewline
        } else {
            Write-Host $leftText -ForegroundColor $leftColor -NoNewline
        }
        Write-Host "   " -NoNewline
        Write-Host $rightText -ForegroundColor $rightColor
    }

    Write-Host ("+" + ("-" * ($listWidth - 2)) + "+   +" + ("-" * ($detailWidth - 2)) + "+") -ForegroundColor DarkCyan

    $selectedLabels = @()
    foreach ($o in $options) { if ($o.Selected) { $selectedLabels += $o.Label } }
    if ($selectedLabels.Count -eq 0) { $summary = "Nothing selected." } else { $summary = [string]::Join(", ", $selectedLabels) }
    Write-Host ""
    Write-Rule $boxWidth "Summary"
    Write-BoxLine $summary $boxWidth $(if ($selectedLabels.Count -eq 0) { [ConsoleColor]::Red } else { [ConsoleColor]::Green })
    Write-Rule $boxWidth ""
    if ($script:message) { Write-Host $script:message -ForegroundColor Yellow }
}

function Toggle-All {
    $anyOff = $false
    foreach ($o in $options) { if (-not $o.Selected) { $anyOff = $true } }
    foreach ($o in $options) { $o.Selected = $anyOff }
    if ($anyOff) { $script:message = "Selected everything." } else { $script:message = "Cleared all selections." }
}

function Clear-Selections {
    foreach ($o in $options) { $o.Selected = $false }
    $script:message = "Cleared all selections."
}

:MenuLoop while ($true) {
    DrawMenu
    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
        "UpArrow"   { $cursor--; if ($cursor -lt 0) { $cursor = $options.Count - 1 }; $message = "" }
        "DownArrow" { $cursor++; if ($cursor -ge $options.Count) { $cursor = 0 }; $message = "" }
        "K"         { $cursor--; if ($cursor -lt 0) { $cursor = $options.Count - 1 }; $message = "" }
        "J"         { $cursor++; if ($cursor -ge $options.Count) { $cursor = 0 }; $message = "" }
        "PageUp"    { $cursor = [Math]::Max(0, $cursor - 4); $message = "" }
        "PageDown"  { $cursor = [Math]::Min($options.Count - 1, $cursor + 4); $message = "" }
        "Spacebar"  { $options[$cursor].Selected = -not $options[$cursor].Selected; $message = "" }
        "A"         { Toggle-All }
        "N"         { Clear-Selections }
        "L"         { Open-LogFolder }
        "Q"         { exit 0 }
        "Enter"     { break MenuLoop }
        "D1"        { Set-Preset "1" }
        "D2"        { Set-Preset "2" }
        "D3"        { Set-Preset "3" }
        "D4"        { Set-Preset "4" }
        "NumPad1"   { Set-Preset "1" }
        "NumPad2"   { Set-Preset "2" }
        "NumPad3"   { Set-Preset "3" }
        "NumPad4"   { Set-Preset "4" }
    }
}

function IsSelected([string]$Key) {
    foreach ($o in $options) { if ($o.Key -eq $Key) { return [bool]$o.Selected } }
    return $false
}

function Write-LogLine([string]$Text) {
    $Text | Tee-Object -FilePath $LogFile -Append | Tee-Object -FilePath $LatestLogFile -Append
}

function Add-ToLogs([string]$Text) {
    Add-Content -LiteralPath $LogFile -Value $Text
    Add-Content -LiteralPath $LatestLogFile -Value $Text
}

function Draw-StepHeader([string]$Title) {
    Clear-Host
    $width = [Math]::Min((Get-ConsoleWidth) - 2, 112)
    Write-Rule $width "Dosty Speak build"
    Write-BoxLine ("Version: " + $Version) $width White
    Write-BoxLine ("Step: " + $Title) $width Cyan
    Write-BoxLine ("Log: " + $LogFile) $width DarkGray
    Write-BoxLine "Live output is shown below. If a tool asks a question, type directly in this window." $width Yellow
    Write-Rule $width ""
    Write-Host ""
}

function Run-Step([string]$Title, [scriptblock]$Block) {
    Draw-StepHeader $Title

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
            Add-ToLogs $line
            if ($line -match "(?i)^warning| warning:|was not found|not found|manual step|required") {
                Write-Host $line -ForegroundColor Yellow
            } elseif ($line -match "(?i)^error:|fatal|failed|exception|cannot|throw") {
                Write-Host $line -ForegroundColor Red
            } elseif ($line -match "(?i)success|finished|done|created|found") {
                Write-Host $line -ForegroundColor Green
            } else {
                Write-Host $line
            }
        }
        $code = $global:LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
    } catch {
        $line = $_.ToString()
        Add-ToLogs $line
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
$summaryWidth = [Math]::Min((Get-ConsoleWidth) - 2, 96)
Write-Rule $summaryWidth "Summary"
foreach ($o in $options) {
    $mark = SelectedText $o.Selected
    Write-BoxLine ("[" + $mark + "] " + $o.Label) $summaryWidth $(if ($o.Selected) { [ConsoleColor]::Green } else { [ConsoleColor]::DarkGray })
}
Write-Rule $summaryWidth ""
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
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ".\scripts\build-android-apk-windows.ps1"
    }
}

Clear-Host
$doneWidth = [Math]::Min((Get-ConsoleWidth) - 2, 96)
Write-Rule $doneWidth "Done"
Write-BoxLine ("Log saved to: " + $LogFile) $doneWidth Green
Write-BoxLine ("Latest log:   " + $LatestLogFile) $doneWidth Green
Write-BoxLine "Build outputs are usually in: dist and dist\android" $doneWidth White
Write-Rule $doneWidth ""
Write-Host ""
