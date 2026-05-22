#!/usr/bin/env bash
set -euo pipefail

echo "Dosty Speak — mobile build dependencies for macOS"
echo "================================================="

need_command() {
  command -v "$1" >/dev/null 2>&1
}

install_brew_if_missing() {
  if need_command brew; then
    return
  fi

  echo "Homebrew is missing."
  echo "Opening Homebrew installer in Terminal..."
  /usr/bin/open "https://brew.sh"
  echo
  echo "Install Homebrew first, then run this script again."
  exit 1
}

install_xcode_cli_if_missing() {
  if xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools: OK"
  else
    echo "Xcode Command Line Tools are missing."
    echo "Starting Apple installer..."
    xcode-select --install || true
    echo
    echo "Finish the Apple installer and run this script again."
    exit 1
  fi
}

install_full_xcode_hint_if_missing() {
  if [[ -d "/Applications/Xcode.app" ]]; then
    echo "Full Xcode: OK"
    return
  fi

  echo
  echo "Full Xcode is not installed."
  echo "It is required for iOS builds."
  echo "Opening Xcode in the Mac App Store..."
  open "macappstore://itunes.apple.com/app/id497799835" || true
  echo
  echo "Install Xcode, open it once, accept the license, then run:"
  echo "  sudo xcodebuild -license accept"
  echo "  sudo xcodebuild -runFirstLaunch"
}

install_brew_if_missing
install_xcode_cli_if_missing

echo
echo "Installing desktop/mobile preview tools..."
brew install cmake ninja qt

echo
echo "Installing Android helper tools where possible..."
brew install --cask temurin@17 || true
brew install --cask android-studio || true
brew install android-platform-tools || true
brew install --cask android-commandlinetools || true

# Try to bootstrap a normal Android SDK location if command line tools are available.
DEFAULT_ANDROID_SDK="$HOME/Library/Android/sdk"
if command -v sdkmanager >/dev/null 2>&1; then
  mkdir -p "$DEFAULT_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$DEFAULT_ANDROID_SDK"
  export ANDROID_HOME="$DEFAULT_ANDROID_SDK"

  echo
  echo "Accepting Android SDK licenses where possible..."
  yes | sdkmanager --licenses >/dev/null 2>&1 || true

  echo "Installing Android SDK platform/build tools/NDK where possible..."
  sdkmanager \
    "platform-tools" \
    "platforms;android-35" \
    "build-tools;35.0.0" \
    "ndk;27.2.12479018" || true
fi

QT_PREFIX="$(brew --prefix qt)"
echo
echo "Qt desktop path:"
echo "  $QT_PREFIX"

echo
echo "Checking Android SDK..."
if [[ -n "${ANDROID_SDK_ROOT:-}" && -d "$ANDROID_SDK_ROOT" ]]; then
  echo "ANDROID_SDK_ROOT: $ANDROID_SDK_ROOT"
else
  DEFAULT_ANDROID_SDK="$HOME/Library/Android/sdk"
  if [[ -d "$DEFAULT_ANDROID_SDK" ]]; then
    echo "Found Android SDK:"
    echo "  $DEFAULT_ANDROID_SDK"
    echo "Recommended export:"
    echo "  export ANDROID_SDK_ROOT=\"$DEFAULT_ANDROID_SDK\""
  else
    echo "Android SDK not found."
    echo "Open Android Studio once and install SDK + NDK:"
    echo "  Android Studio -> Settings -> Languages & Frameworks -> Android SDK"
  fi
fi

echo
echo "Checking Qt Android/iOS kits..."
FOUND_QT_ANDROID="$(find "$HOME/Qt" -maxdepth 3 -type d -name "android_arm64_v8a" 2>/dev/null | head -n1 || true)"
FOUND_QT_IOS="$(find "$HOME/Qt" -maxdepth 3 -type d -name "ios" 2>/dev/null | head -n1 || true)"

if [[ -n "$FOUND_QT_ANDROID" ]]; then
  echo "Qt Android kit found:"
  echo "  $FOUND_QT_ANDROID"
  echo "Recommended export:"
  echo "  export QT_ANDROID_PREFIX=\"$FOUND_QT_ANDROID\""
else
  echo "Qt Android kit not found."
  echo "Homebrew Qt cannot build Android apps."
  echo "This cannot be installed cleanly by Homebrew; use the Qt online installer and select Android arm64-v8a kit:"
  echo "  https://www.qt.io/download-qt-installer-oss"
  open "https://www.qt.io/download-qt-installer-oss" || true
fi

if [[ -n "$FOUND_QT_IOS" ]]; then
  echo "Qt iOS kit found:"
  echo "  $FOUND_QT_IOS"
  echo "Recommended export:"
  echo "  export QT_IOS_PREFIX=\"$FOUND_QT_IOS\""
else
  echo "Qt iOS kit not found."
  echo "Homebrew Qt cannot build iOS apps."
  echo "This cannot be installed cleanly by Homebrew; use the Qt online installer and select iOS kit:"
  echo "  https://www.qt.io/download-qt-installer-oss"
  open "https://www.qt.io/download-qt-installer-oss" || true
fi

install_full_xcode_hint_if_missing

echo
echo "Done."
echo
echo "Mobile preview build:"
echo "  ./scripts/build-mobile-preview-macos.sh"
echo
echo "Run preview directly with logs:"
echo "  ./scripts/run-mobile-preview-macos.sh"


echo
echo "Checking Qt host macOS kit..."
FOUND_QT_MACOS="$(find "$HOME/Qt" -maxdepth 3 -type d -name "macos" 2>/dev/null | while read -r candidate; do
  if [[ -f "$candidate/lib/cmake/Qt6/Qt6Config.cmake" ]]; then echo "$candidate"; break; fi
done)"
if [[ -n "$FOUND_QT_MACOS" ]]; then
  echo "Qt host macOS kit found:"
  echo "  $FOUND_QT_MACOS"
  echo "Recommended export for Android builds:"
  echo "  export QT_HOST_PATH=\"$FOUND_QT_MACOS\""
else
  echo "Qt host macOS kit not found under ~/Qt."
  echo "Android builds work best when Qt Android and Qt macOS host kits come from the same Qt Online Installer version."
fi
