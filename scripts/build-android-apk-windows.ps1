# Dosty Speak - Android APK builder for Windows 10 LTSC 2019 / Windows 11
# Run from project root:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android-apk-windows.ps1

param(
    [switch]$SetupOnly
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 | Out-Null
} catch {}

$ProjectDir = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ProjectDir

$Version = (Get-Content (Join-Path $ProjectDir "VERSION") -Raw).Trim()
$Abi = if ($env:ANDROID_ABI) { $env:ANDROID_ABI } else { "arm64-v8a" }
$BuildDir = Join-Path $ProjectDir "build-android-$Abi"
$DistDir = Join-Path $ProjectDir "dist\android"
$DefaultSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$RequiredNdk = "27.2.12479018"
$CompileSdk = "36"
$BuildToolsVersion = "36.0.0"
$QtWantedVersion = if ($env:QT_VERSION) { $env:QT_VERSION } else { "6.11.1" }

function Say([string]$text) { Write-Host $text -ForegroundColor Cyan }
function Ok([string]$text) { Write-Host $text -ForegroundColor Green }
function Warn([string]$text) { Write-Host $text -ForegroundColor Yellow }
function Fail([string]$text) { Write-Host $text -ForegroundColor Red; throw $text }

function Find-CommandPath([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-AndroidSdk {
    $candidates = @()
    if ($env:ANDROID_SDK_ROOT) { $candidates += $env:ANDROID_SDK_ROOT }
    if ($env:ANDROID_HOME) { $candidates += $env:ANDROID_HOME }
    $candidates += $DefaultSdk
    $candidates += (Join-Path $env:USERPROFILE "AppData\Local\Android\Sdk")
    foreach ($c in $candidates | Select-Object -Unique) {
        if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path }
    }
    New-Item -ItemType Directory -Force -Path $DefaultSdk | Out-Null
    return (Resolve-Path $DefaultSdk).Path
}

function Find-SdkManager([string]$Sdk) {
    $paths = @()
    if ($Sdk) {
        $paths += Join-Path $Sdk "cmdline-tools\latest\bin\sdkmanager.bat"
        $paths += Join-Path $Sdk "cmdline-tools\bin\sdkmanager.bat"
    }
    $cmd = Find-CommandPath "sdkmanager.bat"
    if ($cmd) { $paths += $cmd }
    foreach ($p in $paths | Select-Object -Unique) { if ($p -and (Test-Path $p)) { return $p } }
    return $null
}

function Find-JavaHome {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe"))) { return (Resolve-Path $env:JAVA_HOME).Path }
    $candidates = @(
        "C:\Program Files\Android\Android Studio\jbr",
        "C:\Program Files\Android\Android Studio\jre",
        "C:\Program Files\Eclipse Adoptium\jdk-17*",
        "C:\Program Files\Java\jdk-17*"
    )
    foreach ($c in $candidates) {
        $items = Get-ChildItem $c -Directory -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
        foreach ($i in $items) { if (Test-Path (Join-Path $i.FullName "bin\java.exe")) { return $i.FullName } }
        if (Test-Path (Join-Path $c "bin\java.exe")) { return (Resolve-Path $c).Path }
    }
    return $null
}

function Ensure-Java {
    $javaHome = Find-JavaHome
    if ($javaHome) {
        $env:JAVA_HOME = $javaHome
        $env:Path = (Join-Path $javaHome "bin") + ";" + $env:Path
        Ok "Java found: $javaHome"
        return
    }

    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Warn "Java 17 was not found. Trying to install Temurin 17 using winget..."
        & winget install --id EclipseAdoptium.Temurin.17.JDK --source winget --accept-package-agreements --accept-source-agreements
        $javaHome = Find-JavaHome
        if ($javaHome) {
            $env:JAVA_HOME = $javaHome
            $env:Path = (Join-Path $javaHome "bin") + ";" + $env:Path
            Ok "Java installed: $javaHome"
            return
        }
    }

    Fail "Java 17 not found. Install Android Studio or Temurin 17, then run the builder again."
}

function Download-File([string[]]$Urls, [string]$OutFile) {
    foreach ($url in $Urls) {
        try {
            Warn "Downloading: $url"
            Invoke-WebRequest -Uri $url -OutFile $OutFile -UseBasicParsing
            if (Test-Path $OutFile) { return $true }
        } catch {
            Warn "Download failed: $url"
        }
    }
    return $false
}

function Ensure-CmdlineTools([string]$Sdk) {
    $sdkmanager = Find-SdkManager $Sdk
    if ($sdkmanager) { Ok "sdkmanager found: $sdkmanager"; return $sdkmanager }

    Say "Android SDK Command-line Tools are missing. Installing them automatically..."
    New-Item -ItemType Directory -Force -Path $Sdk | Out-Null
    $tmp = Join-Path $env:TEMP "dosty-android-commandlinetools.zip"
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue

    $urls = @(
        "https://dl.google.com/android/repository/commandlinetools-win-14742923_latest.zip",
        "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip",
        "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    )
    if (!(Download-File $urls $tmp)) {
        Fail "Could not download Android command-line tools. Open Android Studio -> Settings -> Languages & Frameworks -> Android SDK -> SDK Tools -> install Android SDK Command-line Tools."
    }

    $extract = Join-Path $env:TEMP "dosty-android-commandlinetools"
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    Expand-Archive -Path $tmp -DestinationPath $extract -Force

    $latest = Join-Path $Sdk "cmdline-tools\latest"
    Remove-Item $latest -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path (Split-Path $latest -Parent) | Out-Null

    $source = Join-Path $extract "cmdline-tools"
    if (!(Test-Path $source)) { Fail "Downloaded Android command-line tools ZIP has unexpected structure." }
    Move-Item $source $latest

    $sdkmanager = Find-SdkManager $Sdk
    if (!$sdkmanager) { Fail "sdkmanager.bat still not found after installing command-line tools." }
    Ok "sdkmanager installed: $sdkmanager"
    return $sdkmanager
}

function Find-AndroidNdk([string]$Sdk) {
    if ($env:ANDROID_NDK_ROOT -and (Test-Path $env:ANDROID_NDK_ROOT)) { return (Resolve-Path $env:ANDROID_NDK_ROOT).Path }
    $preferred = Join-Path $Sdk ("ndk\" + $RequiredNdk)
    if (Test-Path $preferred) { return (Resolve-Path $preferred).Path }
    $ndkRoot = Join-Path $Sdk "ndk"
    if (Test-Path $ndkRoot) {
        $dirs = Get-ChildItem $ndkRoot -Directory | Sort-Object Name -Descending
        foreach ($d in $dirs) {
            if (Test-Path (Join-Path $d.FullName "build\cmake\android.toolchain.cmake")) { return $d.FullName }
        }
    }
    return $null
}

function Ensure-AndroidPackages([string]$Sdk) {
    Ensure-Java
    $sdkmanager = Ensure-CmdlineTools $Sdk
    Say "Accepting Android SDK licenses..."
    $env:ANDROID_SDK_ROOT = $Sdk
    $env:ANDROID_HOME = $Sdk
    cmd /c "echo y| `"$sdkmanager`" --sdk_root=`"$Sdk`" --licenses 2^>^&1" | ForEach-Object { if ($_ -match "(?i)^warning") { Write-Host $_ -ForegroundColor Yellow } else { Write-Host $_ } }

    Say "Installing Android SDK platform-tools, platform android-$CompileSdk, build-tools $BuildToolsVersion and NDK $RequiredNdk..."
    $sdkArgs = @("--sdk_root=$Sdk", "platform-tools", "platforms;android-$CompileSdk", "build-tools;$BuildToolsVersion", "ndk;$RequiredNdk")
    $cmdLine = "`"$sdkmanager`" " + (($sdkArgs | ForEach-Object { "`"$_`"" }) -join " ") + " 2^>^&1"
    cmd /c $cmdLine | ForEach-Object { if ($_ -match "(?i)^warning") { Write-Host $_ -ForegroundColor Yellow } else { Write-Host $_ } }
    if ($LASTEXITCODE -ne 0) { Fail "sdkmanager failed while installing Android packages." }
}


function Get-QtSearchRoots {
    $roots = @()
    foreach ($v in @($env:QT_ROOT, $env:QT_ROOT_DIR, $env:QTDIR)) {
        if ($v) {
            if (Split-Path $v -Leaf | Where-Object { $_ -match "^(msvc|mingw|android|ios)" }) {
                $roots += (Split-Path (Split-Path $v -Parent) -Parent)
            }
            $roots += $v
        }
    }
    $roots += "C:\Qt"
    $roots += (Join-Path $env:USERPROFILE "Qt")
    $roots += (Join-Path $env:LOCALAPPDATA "Qt")
    $valid = @()
    foreach ($r in $roots) {
        if ($r -and (Test-Path $r)) {
            try { $valid += (Resolve-Path $r).Path } catch {}
        }
    }
    return @($valid | Select-Object -Unique)
}

function Get-PreferredQtRoot {
    $roots = Get-QtSearchRoots
    foreach ($r in $roots) { if ($r -and (Test-Path $r)) { return $r } }
    return (Join-Path $env:USERPROFILE "Qt")
}

function Find-QtMaintenanceTool {
    foreach ($root in Get-QtSearchRoots) {
        foreach ($name in @("MaintenanceTool.exe", "maintenancetool.exe")) {
            $p = Join-Path $root $name
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

function Is-QtAndroidKit([string]$Path) {
    return ($Path -and (Test-Path (Join-Path $Path "lib\cmake\Qt6\Qt6Config.cmake")) -and (Test-Path (Join-Path $Path "lib\cmake\Qt6\qt.toolchain.cmake")) -and ($Path -match "android"))
}

function Is-QtHostKit([string]$Path) {
    return ($Path -and (Test-Path (Join-Path $Path "lib\cmake\Qt6\Qt6Config.cmake")) -and (Test-Path (Join-Path $Path "bin\androiddeployqt.exe")))
}

function Find-QtAndroidKit {
    if (Is-QtAndroidKit $env:QT_ANDROID_PREFIX) { return (Resolve-Path $env:QT_ANDROID_PREFIX).Path }
    foreach ($qtRoot in Get-QtSearchRoots) {
        $direct = Join-Path $qtRoot "$QtWantedVersion\android_arm64_v8a"
        if (Is-QtAndroidKit $direct) { return (Resolve-Path $direct).Path }
        $kits = Get-ChildItem $qtRoot -Recurse -Directory -Filter "android_arm64_v8a" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
        foreach ($k in $kits) { if (Is-QtAndroidKit $k.FullName) { return $k.FullName } }
    }
    return $null
}

function Find-QtHostKit([string]$AndroidKit) {
    if (Is-QtHostKit $env:QT_HOST_PATH) { return (Resolve-Path $env:QT_HOST_PATH).Path }
    if ($AndroidKit) {
        $versionDir = Split-Path $AndroidKit -Parent
        foreach ($name in @("msvc2022_64", "msvc2019_64", "mingw_64")) {
            $p = Join-Path $versionDir $name
            if (Is-QtHostKit $p) { return (Resolve-Path $p).Path }
        }
    }
    foreach ($qtRoot in Get-QtSearchRoots) {
        foreach ($name in @("msvc2022_64", "msvc2019_64", "mingw_64")) {
            $direct = Join-Path $qtRoot "$QtWantedVersion\$name"
            if (Is-QtHostKit $direct) { return (Resolve-Path $direct).Path }
        }
        $kits = Get-ChildItem $qtRoot -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @("msvc2022_64", "msvc2019_64", "mingw_64") } | Sort-Object FullName -Descending
        foreach ($k in $kits) { if (Is-QtHostKit $k.FullName) { return $k.FullName } }
    }
    return $null
}

function Add-ToolDirectoryToPath([string]$ToolPath) {
    if (!$ToolPath -or !(Test-Path $ToolPath)) { return }
    $dir = Split-Path $ToolPath -Parent
    if (!$dir -or !(Test-Path $dir)) { return }
    $parts = @($env:Path -split ";" | Where-Object { $_ })
    foreach ($p in $parts) {
        if ($p.TrimEnd("\") -ieq $dir.TrimEnd("\")) { return }
    }
    $env:Path = $dir + ";" + $env:Path
}

function Test-ToolPath([string]$Path, [string]$FileName) {
    if (!$Path) { return $null }
    if (Test-Path $Path -PathType Container) { $Path = Join-Path $Path $FileName }
    if (Test-Path $Path -PathType Leaf) {
        try { return (Resolve-Path $Path).Path } catch { return $Path }
    }
    return $null
}

function Find-ToolInCandidates([string]$FileName, [string[]]$Candidates) {
    $cmd = Find-CommandPath $FileName
    if ($cmd) { return $cmd }
    foreach ($candidate in $Candidates | Select-Object -Unique) {
        $tool = Test-ToolPath $candidate $FileName
        if ($tool) { return $tool }
    }
    return $null
}

function Find-CmakePath([string]$QtHost) {
    $candidates = @()
    if ($env:CMAKE_EXE) { $candidates += $env:CMAKE_EXE }
    if ($env:CMAKE_ROOT) { $candidates += Join-Path $env:CMAKE_ROOT "bin\cmake.exe" }
    if ($QtHost) {
        $qtVersionDir = Split-Path $QtHost -Parent
        $qtRoot = Split-Path $qtVersionDir -Parent
        $candidates += Join-Path $qtRoot "Tools\CMake_64\bin\cmake.exe"
        $candidates += Join-Path $qtRoot "Tools\CMake\bin\cmake.exe"
    }
    foreach ($qtRoot in Get-QtSearchRoots) {
        $candidates += Join-Path $qtRoot "Tools\CMake_64\bin\cmake.exe"
        $candidates += Join-Path $qtRoot "Tools\CMake\bin\cmake.exe"
        $toolsRoot = Join-Path $qtRoot "Tools"
        if (Test-Path $toolsRoot) {
            $candidates += (Get-ChildItem $toolsRoot -Recurse -Filter "cmake.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }
    }
    $candidates += "C:\Program Files\CMake\bin\cmake.exe"
    $candidates += "C:\Program Files (x86)\CMake\bin\cmake.exe"
    $candidates += "C:\msys64\ucrt64\bin\cmake.exe"
    $candidates += "C:\msys64\mingw64\bin\cmake.exe"
    $candidates += "C:\msys64\usr\bin\cmake.exe"
    $vsRoot = "C:\Program Files\Microsoft Visual Studio"
    if (Test-Path $vsRoot) {
        $candidates += (Get-ChildItem $vsRoot -Recurse -Filter "cmake.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    return Find-ToolInCandidates "cmake.exe" $candidates
}

function Find-NinjaPath([string]$QtHost) {
    $candidates = @()
    if ($env:NINJA_EXE) { $candidates += $env:NINJA_EXE }
    if ($QtHost) {
        $qtVersionDir = Split-Path $QtHost -Parent
        $qtRoot = Split-Path $qtVersionDir -Parent
        $candidates += Join-Path $qtRoot "Tools\Ninja\ninja.exe"
        $candidates += Join-Path $qtRoot "Tools\mingw1310_64\bin\ninja.exe"
        $candidates += Join-Path $qtRoot "Tools\mingw1120_64\bin\ninja.exe"
        $candidates += Join-Path $qtRoot "Tools\mingw900_64\bin\ninja.exe"
    }
    foreach ($qtRoot in Get-QtSearchRoots) {
        $candidates += Join-Path $qtRoot "Tools\Ninja\ninja.exe"
        $toolsRoot = Join-Path $qtRoot "Tools"
        if (Test-Path $toolsRoot) {
            $candidates += (Get-ChildItem $toolsRoot -Recurse -Filter "ninja.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }
    }
    $candidates += "C:\Program Files\CMake\bin\ninja.exe"
    $candidates += "C:\Program Files (x86)\CMake\bin\ninja.exe"
    $candidates += "C:\msys64\ucrt64\bin\ninja.exe"
    $candidates += "C:\msys64\mingw64\bin\ninja.exe"
    $candidates += "C:\msys64\usr\bin\ninja.exe"
    $vsRoot = "C:\Program Files\Microsoft Visual Studio"
    if (Test-Path $vsRoot) {
        $candidates += (Get-ChildItem $vsRoot -Recurse -Filter "ninja.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    return Find-ToolInCandidates "ninja.exe" $candidates
}

function Find-BuildToolsBin([string]$Sdk) {
    $preferred = Join-Path $Sdk ("build-tools\" + $BuildToolsVersion)
    if (Test-Path (Join-Path $preferred "apksigner.bat")) { return $preferred }
    $root = Join-Path $Sdk "build-tools"
    if (!(Test-Path $root)) { return $null }
    $dirs = Get-ChildItem $root -Directory | Sort-Object Name -Descending
    foreach ($d in $dirs) { if (Test-Path (Join-Path $d.FullName "apksigner.bat")) { return $d.FullName } }
    return $null
}

function Stop-GradleDaemons([string]$BuildRoot) {
    $gradlew = Join-Path $BuildRoot "android-build\gradlew.bat"
    if (Test-Path $gradlew) {
        try {
            & $gradlew --stop | Out-Null
        } catch {
            Warn "Could not stop Gradle daemon cleanly."
        }
    }
}

function Test-PythonCommand([string]$Exe, [string[]]$PrefixArgs) {
    try {
        & $Exe @PrefixArgs -c "import sys; print(sys.version)" | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Find-PythonForAqt {
    $nativeCandidates = @()
    $cmd = Find-CommandPath "python.exe"
    if ($cmd) { $nativeCandidates += $cmd }
    $nativeCandidates += (Get-ChildItem (Join-Path $env:LOCALAPPDATA "Programs\Python") -Recurse -Filter "python.exe" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    $nativeCandidates += (Get-ChildItem "C:\Program Files\Python*" -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName "python.exe" })
    foreach ($p in $nativeCandidates | Select-Object -Unique) {
        if ($p -and (Test-Path $p) -and (Test-PythonCommand $p @())) { return @{ Exe=$p; Args=@() } }
    }

    # Avoid the Windows py.exe launcher here. On some Windows 10/11 systems it
    # opens an interactive Python prompt when called from nested PowerShell,
    # which makes the builder look frozen. Use a real python.exe/python3.exe.
    $python3 = Find-CommandPath "python3.exe"
    if ($python3 -and (Test-PythonCommand $python3 @())) { return @{ Exe=$python3; Args=@() } }

    return $null
}

function Ensure-PythonForAqt {
    $py = Find-PythonForAqt
    if ($py) { return $py }

    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Warn "Python was not found. Trying to install Python 3 using winget..."
        & winget install --id Python.Python.3.12 --source winget --accept-package-agreements --accept-source-agreements
        $py = Find-PythonForAqt
        if ($py) { return $py }
    }

    return $null
}

function Invoke-PythonModule {
    param(
        [Parameter(Mandatory=$true)] [hashtable]$Py,
        [Parameter(Mandatory=$true)] [string[]]$CommandArgs
    )

    # Windows PowerShell 5.1 can silently eat remaining args in some calling
    # patterns. Build the argv explicitly and require -c or -m so Python can
    # never open the interactive prompt and freeze the builder.
    $exe = [string]$Py["Exe"]
    $fullArgs = @()

    if ($Py.ContainsKey("Args") -and $null -ne $Py["Args"]) {
        foreach ($a in @($Py["Args"])) {
            if ($null -ne $a -and [string]$a -ne "") { $fullArgs += [string]$a }
        }
    }

    foreach ($a in @($CommandArgs)) {
        if ($null -ne $a -and [string]$a -ne "") { $fullArgs += [string]$a }
    }

    $hasRealCommand = $false
    foreach ($a in $fullArgs) {
        if ($a -eq "-c" -or $a -eq "-m") { $hasRealCommand = $true }
    }

    if (!$hasRealCommand) {
        Write-Host "Python command is incomplete. Refusing to open interactive Python." -ForegroundColor Red
        Write-Host ("Attempted command: " + $exe + " " + ($fullArgs -join " ")) -ForegroundColor Red
        return 99
    }

    Write-Host ("Running Python command: " + $exe + " " + ($fullArgs -join " ")) -ForegroundColor DarkGray
    & $exe @fullArgs
    return $LASTEXITCODE
}

function Try-InstallQtWithAqt {
    Say "Qt Android kit is missing. Trying automatic Qt install using aqtinstall..."
    $py = Ensure-PythonForAqt
    if (!$py) {
        Warn "Python is not available, so automatic Qt install through aqtinstall cannot run."
        return $false
    }

    $qtRoot = Get-PreferredQtRoot
    New-Item -ItemType Directory -Force -Path $qtRoot | Out-Null

    $testCode = Invoke-PythonModule -Py $py -CommandArgs @("-c", "import sys; print('Python OK:', sys.version.split()[0])")
    if ($testCode -ne 0) {
        Warn "Python test command failed, so automatic Qt install cannot continue."
        return $false
    }

    Say "Installing/updating aqtinstall..."
    $code = Invoke-PythonModule -Py $py -CommandArgs @("-m", "pip", "install", "--user", "--upgrade", "pip", "aqtinstall")
    if ($code -ne 0) {
        Warn "pip/aqtinstall failed."
        return $false
    }

    $hostKit = Join-Path $qtRoot "$QtWantedVersion\msvc2022_64"
    $androidKit = Join-Path $qtRoot "$QtWantedVersion\android_arm64_v8a"

    if (!(Is-QtHostKit $hostKit)) {
        Say "Installing Qt host kit $QtWantedVersion msvc2022_64 to $qtRoot ..."
        $code = Invoke-PythonModule -Py $py -CommandArgs @("-m", "aqt", "install-qt", "windows", "desktop", $QtWantedVersion, "win64_msvc2022_64", "-O", $qtRoot)
        if ($code -ne 0) {
            Warn "Automatic Qt host kit install failed."
        }
    }

    if (!(Is-QtAndroidKit $androidKit)) {
        Say "Installing Qt Android kit $QtWantedVersion android_arm64_v8a to $qtRoot ..."
        $code = Invoke-PythonModule -Py $py -CommandArgs @("-m", "aqt", "install-qt", "windows", "android", $QtWantedVersion, "android_arm64_v8a", "-O", $qtRoot)
        if ($code -ne 0) {
            Warn "Automatic Qt Android kit install failed."
        }
    }

    $qa = Find-QtAndroidKit
    $qh = Find-QtHostKit $qa
    return [bool]($qa -and $qh)
}

function Open-QtInstallerHelp {
    $installerUrl = "https://download.qt.io/official_releases/online_installers/qt-online-installer-windows-x64-online.exe"
    $installer = Join-Path $env:USERPROFILE "Downloads\qt-online-installer-windows-x64-online.exe"
    $qtRoot = Get-PreferredQtRoot

    Write-Host ""
    Write-Host "+------------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "| Manual step required: Qt Android kit                            |" -ForegroundColor Yellow
    Write-Host "+------------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "The Android SDK and NDK are installed, but Qt for Android is missing."
    Write-Host "The builder now searches C:\Qt, $env:USERPROFILE\Qt, LOCALAPPDATA\Qt and custom QT_* variables."
    Write-Host "Install or add these Qt components:"
    Write-Host "  Qt $QtWantedVersion -> MSVC 2022 64-bit"
    Write-Host "  Qt $QtWantedVersion -> Android -> Android arm64-v8a"
    Write-Host "Expected paths can be for example:"
    Write-Host "  $qtRoot\$QtWantedVersion\msvc2022_64"
    Write-Host "  $qtRoot\$QtWantedVersion\android_arm64_v8a"
    Write-Host ""

    $maintenance = Find-QtMaintenanceTool
    if ($maintenance) {
        Say "Opening existing Qt Maintenance Tool instead of a new installer..."
        Write-Host "Use Add or remove components, then select the Android arm64-v8a and MSVC 2022 64-bit kits."
        Start-Process $maintenance | Out-Null
        return
    }

    if (!(Test-Path $installer)) {
        try {
            Say "Downloading Qt Online Installer to Downloads..."
            Invoke-WebRequest -Uri $installerUrl -OutFile $installer -UseBasicParsing
        } catch {
            Warn "Could not download Qt installer automatically. Opening the download page instead."
            Start-Process $installerUrl | Out-Null
            return
        }
    }

    if (Test-Path $installer) {
        Say "Opening Qt Online Installer..."
        Start-Process $installer | Out-Null
    }
}

function Ensure-QtAndroidKitsInteractive {
    while ($true) {
        $qtAndroid = Find-QtAndroidKit
        $qtHost = Find-QtHostKit $qtAndroid
        if ($qtAndroid -and $qtHost) {
            Ok "Qt Android kit found: $qtAndroid"
            Ok "Qt host kit found: $qtHost"
            return @{ Android=$qtAndroid; Host=$qtHost }
        }

        if (Try-InstallQtWithAqt) {
            $qtAndroid = Find-QtAndroidKit
            $qtHost = Find-QtHostKit $qtAndroid
            Ok "Qt installed/found."
            return @{ Android=$qtAndroid; Host=$qtHost }
        }

        Open-QtInstallerHelp
        Write-Host ""
        $answer = Read-Host "After Qt install finishes, press Enter to check again, or type Q to stop"
        if ($answer -match "^[Qq]$") { Fail "Qt Android kit not found. Install Qt Android arm64-v8a and rerun the builder." }
    }
}

function Ensure-QtKitHints {
    $qtAndroid = Find-QtAndroidKit
    if ($qtAndroid) { Ok "Qt Android kit found: $qtAndroid" } else { Warn "Qt Android kit not found. Expected for example: $env:USERPROFILE\Qt\$QtWantedVersion\android_arm64_v8a" }
    $qtHost = Find-QtHostKit $qtAndroid
    if ($qtHost) { Ok "Qt host kit found: $qtHost" } else { $qr = Get-PreferredQtRoot; Warn "Qt host kit with androiddeployqt.exe not found. Expected for example: $qr\$QtWantedVersion\msvc2022_64" }
}

Say "Dosty Speak - Android APK builder for Windows"
Say "==============================================="
Write-Host "Version: $Version"
Write-Host "ABI:     $Abi"
Write-Host ""

$Sdk = Find-AndroidSdk
Ok "Android SDK path: $Sdk"
Ensure-AndroidPackages $Sdk
Ensure-QtKitHints

if ($SetupOnly) {
    $setupQtAndroid = Find-QtAndroidKit
    $setupQtHost = Find-QtHostKit $setupQtAndroid
    $setupCmake = Find-CmakePath $setupQtHost
    $setupNinja = Find-NinjaPath $setupQtHost
    if ($setupCmake) { Ok "CMake found: $setupCmake" } else { Warn "CMake not found. Install Qt Tools -> CMake or put cmake.exe in PATH." }
    if ($setupNinja) { Ok "Ninja found: $setupNinja" } else { Warn "Ninja not found. Install Qt Tools -> Ninja or put ninja.exe in PATH." }
    Write-Host ""
    Ok "Android dependency check finished."
    Write-Host "If Qt Android kit is missing, install it with Qt Online Installer:"
    Write-Host "  Qt $QtWantedVersion -> Android -> Android arm64-v8a"
    Write-Host "  Qt $QtWantedVersion -> MSVC 2022 64-bit"
    Write-Host "In full Android build mode the script will also try automatic install with aqtinstall."
    exit 0
}

$Ndk = Find-AndroidNdk $Sdk
if (!$Ndk) { Fail "Android NDK not found after sdkmanager install. Open Android Studio -> SDK Tools -> NDK, or rerun this builder." }

$QtKits = Ensure-QtAndroidKitsInteractive
$QtAndroid = $QtKits.Android
$QtHost = $QtKits.Host

$Cmake = Find-CmakePath $QtHost
$Ninja = Find-NinjaPath $QtHost
if (!$Cmake) { Fail "cmake.exe not found. Install CMake, or install Qt Tools -> CMake with Qt Maintenance Tool." }
if (!$Ninja) { Fail "ninja.exe not found. Install Ninja, or install Qt Tools -> Ninja with Qt Maintenance Tool." }
Add-ToolDirectoryToPath $Cmake
Add-ToolDirectoryToPath $Ninja

$env:ANDROID_SDK_ROOT = $Sdk
$env:ANDROID_HOME = $Sdk
$env:ANDROID_NDK_ROOT = $Ndk
$env:QT_ANDROID_PREFIX = $QtAndroid
$env:QT_HOST_PATH = $QtHost

Write-Host ""
Write-Host "Using:"
Write-Host "  Android SDK: $Sdk"
Write-Host "  Android NDK: $Ndk"
Write-Host "  Qt Android:  $QtAndroid"
Write-Host "  Qt Host:     $QtHost"
Write-Host "  CMake:       $Cmake"
Write-Host "  Ninja:       $Ninja"
Write-Host ""

if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }

& $Cmake -S mobile -B $BuildDir `
    -G Ninja `
    -DCMAKE_PREFIX_PATH="$QtAndroid" `
    -DQt6_DIR="$QtAndroid\lib\cmake\Qt6" `
    -DQT_HOST_PATH="$QtHost" `
    -DANDROID_SDK_ROOT="$Sdk" `
    -DANDROID_NDK_ROOT="$Ndk" `
    -DANDROID_ABI="$Abi" `
    -DANDROID_PLATFORM="android-23" `
    -DQT_ANDROID_COMPILE_SDK_VERSION="$CompileSdk" `
    -DCMAKE_TOOLCHAIN_FILE="$QtAndroid\lib\cmake\Qt6\qt.toolchain.cmake" `
    -DCMAKE_BUILD_TYPE=Release
if ($LASTEXITCODE -ne 0) { Fail "CMake configure failed." }

& $Cmake --build $BuildDir --parallel
if ($LASTEXITCODE -ne 0) { Fail "Android build failed." }

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$Unsigned = Get-ChildItem $BuildDir -Recurse -Filter "*.apk" | Where-Object { $_.Name -match "unsigned|release|apk" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (!$Unsigned) { Fail "APK was not found after build." }

$Tools = Find-BuildToolsBin $Sdk
$Signed = Join-Path $DistDir "DostySpeak-Mobile-$Version-$Abi-debug-signed.apk"
$Aligned = Join-Path $DistDir "DostySpeak-Mobile-$Version-$Abi-debug-signed-aligned.apk"

if ($Tools -and (Test-Path (Join-Path $Tools "apksigner.bat"))) {
    $Keystore = Join-Path $env:USERPROFILE ".android\debug.keystore"
    New-Item -ItemType Directory -Force -Path (Split-Path $Keystore -Parent) | Out-Null
    if (!(Test-Path $Keystore)) {
        $keytool = Find-CommandPath "keytool.exe"
        if (!$keytool -and $env:JAVA_HOME) { $keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe" }
        if (!$keytool -or !(Test-Path $keytool)) { Fail "keytool.exe not found, cannot create debug keystore." }
        & $keytool -genkeypair -v -keystore $Keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" | Out-Null
    }
    $Zipalign = Join-Path $Tools "zipalign.exe"
    if (Test-Path $Zipalign) { & $Zipalign -f 4 $Unsigned.FullName $Aligned } else { Copy-Item $Unsigned.FullName $Aligned -Force }
    & (Join-Path $Tools "apksigner.bat") sign --ks $Keystore --ks-pass pass:android --key-pass pass:android --out $Signed $Aligned
    if ($LASTEXITCODE -ne 0) { Fail "apksigner failed." }
    & (Join-Path $Tools "apksigner.bat") verify $Signed
    if ($LASTEXITCODE -ne 0) { Fail "APK signature verification failed." }
} else {
    Copy-Item $Unsigned.FullName $Signed -Force
    Warn "apksigner was not found. APK copied but may be unsigned."
}

Write-Host ""
Ok "Done. Installable APK:"
Write-Host "  $Signed"
Stop-GradleDaemons $BuildDir
exit 0
