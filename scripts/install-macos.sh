#!/usr/bin/env bash
set -euo pipefail

echo "Dosty Speak — macOS installer"
echo "============================="

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh/"
  exit 1
fi

brew install cmake qt || true

QT_PREFIX="$(brew --prefix qt)"
export PATH="$QT_PREFIX/bin:$PATH"

APP_NAME="Dosty Speak"
TARGET_APP="$HOME/Applications/$APP_NAME.app"

rm -rf build-macos
cmake -S . -B build-macos \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$QT_PREFIX"

cmake --build build-macos -j"$(sysctl -n hw.ncpu)"

BUILT_APP="$(find build-macos -maxdepth 3 -name 'dosty-speak.app' -type d | head -n 1)"
if [[ -z "$BUILT_APP" ]]; then
  echo "Could not find built dosty-speak.app bundle."
  find build-macos -maxdepth 3 -print
  exit 1
fi

mkdir -p "$HOME/Applications"
rm -rf "$TARGET_APP"
cp -R "$BUILT_APP" "$TARGET_APP"

CONTENTS="$TARGET_APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Remove older broken resource placement from previous builds.
rm -rf "$MACOS/resources"

# macdeployqt should run before final resource copy/signing.
if command -v macdeployqt >/dev/null 2>&1; then
  echo "Running macdeployqt..."
  macdeployqt "$TARGET_APP" -verbose=1 || {
    echo
    echo "macdeployqt reported errors. Continuing because the app may still run on this Mac with Homebrew Qt installed."
    echo "If the app immediately closes, run it from Terminal with:"
    echo "  \"$TARGET_APP/Contents/MacOS/dosty-speak\""
  }
else
  echo "macdeployqt not found in PATH."
  echo "Try: export PATH=\"$QT_PREFIX/bin:\$PATH\""
fi

# Put app resources inside the correct bundle Resources folder after macdeployqt.
mkdir -p "$RESOURCES"
rm -rf "$RESOURCES/resources"
cp -R resources "$RESOURCES/resources"

if [[ -f "resources/icons/dosty-speak.icns" ]]; then
  cp "resources/icons/dosty-speak.icns" "$RESOURCES/dosty-speak.icns"
fi

VERSION="$(grep -E 'VERSION [0-9]+\.[0-9]+\.[0-9]+' CMakeLists.txt | head -n1 | sed -E 's/.*VERSION ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
if [[ -f "$CONTENTS/Info.plist" ]] && command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$CONTENTS/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$CONTENTS/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier cz.dosty.dostyspeak" "$CONTENTS/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS/Info.plist" 2>/dev/null || true
fi

# Remove extended attributes that can make local unsigned apps annoying.
xattr -cr "$TARGET_APP" 2>/dev/null || true

# Ad-hoc sign after all files are in place. This fixes broken signature states after macdeployqt/resource copy.
if command -v codesign >/dev/null 2>&1; then
  echo "Ad-hoc signing app bundle..."
  codesign --force --deep --sign - "$TARGET_APP" || true
fi

echo
echo "Installed:"
echo "  $TARGET_APP"
echo
echo "Run it with:"
echo "  open \"$TARGET_APP\""
echo
echo "If it closes immediately, run this and send the output:"
echo "  \"$TARGET_APP/Contents/MacOS/dosty-speak\""
