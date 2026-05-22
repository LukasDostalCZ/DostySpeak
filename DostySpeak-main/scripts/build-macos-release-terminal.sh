#!/usr/bin/env bash
set -euo pipefail

echo "Dosty Speak - macOS release builder"
echo

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh/"
  exit 1
fi

brew install cmake qt create-dmg || true

QT_PREFIX="$(brew --prefix qt)"
export PATH="$QT_PREFIX/bin:$PATH"

VERSION="$(grep -E 'VERSION [0-9]+\.[0-9]+\.[0-9]+' CMakeLists.txt | head -n1 | sed -E 's/.*VERSION ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"

rm -rf build-macos dist/DostySpeak-macOS "dist/DostySpeak-$VERSION.dmg"
mkdir -p dist

cmake -S . -B build-macos \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$QT_PREFIX"

cmake --build build-macos -j"$(sysctl -n hw.ncpu)"

BUILT_APP="$(find build-macos -maxdepth 3 -name 'dosty-speak.app' -type d | head -n 1)"
if [[ -z "$BUILT_APP" ]]; then
  echo "Could not find built dosty-speak.app bundle."
  exit 1
fi

APP_DIR="dist/DostySpeak-macOS"
APP="$APP_DIR/Dosty Speak.app"
mkdir -p "$APP_DIR"
rm -rf "$APP"
cp -R "$BUILT_APP" "$APP"

rm -rf "$APP/Contents/MacOS/resources"

if command -v macdeployqt >/dev/null 2>&1; then
  macdeployqt "$APP" -verbose=1 || true
fi

mkdir -p "$APP/Contents/Resources"
rm -rf "$APP/Contents/Resources/resources"
cp -R resources "$APP/Contents/Resources/resources"

if [[ -f "resources/icons/dosty-speak.icns" ]]; then
  cp "resources/icons/dosty-speak.icns" "$APP/Contents/Resources/dosty-speak.icns"
fi

xattr -cr "$APP" 2>/dev/null || true
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" || true
fi

tar -C "$APP_DIR" -czf "dist/DostySpeak-macOS-$VERSION.tar.gz" "Dosty Speak.app"
echo "Created: dist/DostySpeak-macOS-$VERSION.tar.gz"

if command -v create-dmg >/dev/null 2>&1; then
  create-dmg \
    --volname "Dosty Speak" \
    --window-pos 200 120 \
    --window-size 620 360 \
    --icon-size 100 \
    --app-drop-link 460 180 \
    "dist/DostySpeak-$VERSION.dmg" \
    "$APP" || true

  [[ -f "dist/DostySpeak-$VERSION.dmg" ]] && echo "Created: dist/DostySpeak-$VERSION.dmg"
fi

echo
echo "Done. Outputs are in dist/"
