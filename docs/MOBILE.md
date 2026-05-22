## Mobile build, Android and iOS

Mobile code lives in:

```text
mobile/
```

The mobile app uses Qt Quick/QML. The desktop Qt Widgets UI is not used on mobile.

### 1. Install/check dependencies on macOS

Run:

```bash
cd ~/Dev/dosty-speak
chmod +x scripts/install-mobile-build-deps-macos.sh
./scripts/install-mobile-build-deps-macos.sh
```

The script installs/checks what it reasonably can:

```text
Homebrew
Xcode Command Line Tools
cmake
ninja
desktop Qt for macOS preview
Android Studio
JDK 17
Android platform tools
```

The script also detects and prints paths for:

```text
Android SDK
Android NDK
Qt Android kit
Qt iOS kit
Xcode
```

Important limitation: Qt Android and Qt iOS kits are not available from Homebrew Qt. Install them with the official Qt online installer when the script says they are missing.

### 2. Build mobile preview on macOS

This tests the mobile UI as a normal macOS app:

```bash
chmod +x scripts/build-mobile-preview-macos.sh
./scripts/build-mobile-preview-macos.sh
open "build-mobile-preview-macos/dosty-speak-mobile.app"
```

If the app closes immediately, run it directly to see the log:

```bash
chmod +x scripts/run-mobile-preview-macos.sh
./scripts/run-mobile-preview-macos.sh
```

### 3. Android APK

Install through Android Studio first if missing:

```text
Android SDK
Android NDK
Android platform
Qt Android arm64 kit
```

Then run:

```bash
chmod +x scripts/print-mobile-env-hints.sh
./scripts/print-mobile-env-hints.sh
```

Copy/export the printed variables if needed, then build:

```bash
chmod +x scripts/build-android-apk.sh
./scripts/build-android-apk.sh
```

The APK is usually created under:

```text
build-android-arm64-v8a/android-build/build/outputs/apk/
```

Android speech uses native Android `TextToSpeech`:

```text
mobile/android/src/cz/dosty/speak/DostyTts.java
```

### 4. iOS build

Install first:

```text
Full Xcode
Qt iOS kit
Apple signing/team setup
```

Then run:

```bash
chmod +x scripts/print-mobile-env-hints.sh
./scripts/print-mobile-env-hints.sh

chmod +x scripts/build-ios.sh
./scripts/build-ios.sh
```

If signing fails, open the generated Xcode project and select your Team manually:

```bash
open "build-ios/DostySpeakMobile.xcodeproj"
```

iOS speech uses native `AVSpeechSynthesizer`:

```text
mobile/IosTts.mm
```

### Mobile feature status

Works in the mobile scaffold:

```text
touch UI
large text input
Speak / Save / Stop buttons
quick phrase buttons
phrase cards
language selector
speech speed slider
Android native TextToSpeech bridge
iOS native AVSpeechSynthesizer bridge
```

Still planned:

```text
persistent mobile phrase storage
full mobile preset management
mobile autocomplete from saved phrases
Piper as native embedded mobile engine
online Google/Edge mobile voices
```

Desktop Python/Piper/edge-tts cannot be copied 1:1 to iOS and Android because mobile systems do not allow the same free runtime installation and external process execution as desktop systems.
