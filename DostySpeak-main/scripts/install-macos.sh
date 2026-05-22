#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Dosty Speak"
TARGET_APP="$HOME/Applications/$APP_NAME.app"
BUILD_DIR="build-macos"
DIST_DIR="dist"

if [[ -f VERSION ]]; then
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION)"
else
  DOSTY_SPEAK_VERSION="0.0.0"
fi

echo "Dosty Speak — macOS desktop builder"
echo "==================================="
echo "Source version: $DOSTY_SPEAK_VERSION"
echo

# Prefer the official Qt macOS kit because Homebrew Qt often produces noisy/incomplete macdeployqt output.
QT_PREFIX=""
if [[ -n "${QT_MACOS_PREFIX:-}" && -x "$QT_MACOS_PREFIX/bin/qt-cmake" ]]; then
  QT_PREFIX="$QT_MACOS_PREFIX"
elif [[ -n "${QT_HOST_PATH:-}" && -x "$QT_HOST_PATH/bin/qt-cmake" ]]; then
  QT_PREFIX="$QT_HOST_PATH"
elif [[ -x "$HOME/Qt/6.11.1/macos/bin/qt-cmake" ]]; then
  QT_PREFIX="$HOME/Qt/6.11.1/macos"
elif compgen -G "$HOME/Qt/*/macos/bin/qt-cmake" >/dev/null; then
  QT_PREFIX="$(ls -d "$HOME"/Qt/*/macos | sort -V | tail -n 1)"
elif [[ -x "/opt/homebrew/opt/qt/bin/qt-cmake" ]]; then
  QT_PREFIX="/opt/homebrew/opt/qt"
elif [[ -x "/usr/local/opt/qt/bin/qt-cmake" ]]; then
  QT_PREFIX="/usr/local/opt/qt"
fi

if [[ -z "$QT_PREFIX" ]]; then
  if command -v brew >/dev/null 2>&1; then
    brew install cmake qt
    QT_PREFIX="$(brew --prefix qt)"
  else
    echo "Qt was not found."
    echo "Install Qt 6 for macOS or Homebrew Qt, then run this builder again."
    exit 1
  fi
fi

echo "Using Qt:"
echo "  $QT_PREFIX"
echo

QT_CMAKE="$QT_PREFIX/bin/qt-cmake"
MACDEPLOYQT="$QT_PREFIX/bin/macdeployqt"

mkdir -p "$HOME/Applications" "$DIST_DIR"
rm -rf "$BUILD_DIR"

"$QT_CMAKE" -S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" -j"$(sysctl -n hw.ncpu)"
BUILD_COMPILED_OK=1

BUILT_APP="$BUILD_DIR/dosty-speak.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "Build finished, but app bundle was not found:"
  echo "  $BUILT_APP"
  exit 1
fi

echo
echo "Installing app to:"
echo "  $TARGET_APP"
rm -rf "$TARGET_APP"
cp -R "$BUILT_APP" "$TARGET_APP"
chmod +x "$TARGET_APP/Contents/MacOS/dosty-speak" || true

DOSTY_MACDEPLOYQT_TIMEOUT="${DOSTY_MACDEPLOYQT_TIMEOUT:-90}"

if [[ -x "$MACDEPLOYQT" ]]; then
  echo
  echo "Deploying Qt frameworks into app bundle..."
  DEPLOY_LOG="$BUILD_DIR/macdeployqt.log"
  if perl -e 'alarm shift; exec @ARGV' "$DOSTY_MACDEPLOYQT_TIMEOUT" "$MACDEPLOYQT" "$TARGET_APP" -verbose=0 >"$DEPLOY_LOG" 2>&1; then
    echo "Qt deployment: OK"
  else
    echo "Qt deployment reported issues, but the C++ app compile already succeeded."
    echo "The app may still run on this Mac, but release packaging may not be portable."
    echo "Full deploy log:"
    echo "  $DEPLOY_LOG"
    echo
    tail -n 25 "$DEPLOY_LOG" || true
  fi
fi

echo
echo "Ad-hoc signing app bundle..."
codesign --force --deep --sign - "$TARGET_APP" >/dev/null 2>&1 || true

echo
echo "Verifying installed app bundle..."
if [[ ! -x "$TARGET_APP/Contents/MacOS/dosty-speak" ]]; then
  echo "Installed app binary is missing or not executable:"
  echo "  $TARGET_APP/Contents/MacOS/dosty-speak"
  exit 1
fi

echo "Installed app version: $DOSTY_SPEAK_VERSION"
echo "Installed:"
echo "  $TARGET_APP"

# Always create release artifacts, because user expects desktop build to populate dist.
ZIP_NAME="DostySpeak-macOS-$DOSTY_SPEAK_VERSION.zip"
DMG_NAME="DostySpeak-macOS-$DOSTY_SPEAK_VERSION.dmg"
rm -f "$DIST_DIR/$ZIP_NAME" "$DIST_DIR/$DMG_NAME"

echo
echo "Creating desktop release ZIP:"
echo "  $DIST_DIR/$ZIP_NAME"
ditto -c -k --keepParent "$TARGET_APP" "$DIST_DIR/$ZIP_NAME"

if command -v hdiutil >/dev/null 2>&1; then
  TMP_DMG_DIR="$(mktemp -d)"
  cp -R "$TARGET_APP" "$TMP_DMG_DIR/"
  ln -s /Applications "$TMP_DMG_DIR/Applications" 2>/dev/null || true
  echo "Creating desktop release DMG:"
  echo "  $DIST_DIR/$DMG_NAME"
  hdiutil create \
    -volname "Dosty Speak $DOSTY_SPEAK_VERSION" \
    -srcfolder "$TMP_DMG_DIR" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME" >/dev/null
  rm -rf "$TMP_DMG_DIR"
fi

echo
echo "Desktop release files:"
find "$DIST_DIR" -maxdepth 1 \( -name "DostySpeak-macOS-$DOSTY_SPEAK_VERSION.zip" -o -name "DostySpeak-macOS-$DOSTY_SPEAK_VERSION.dmg" \) -print | sed 's/^/  /'

echo
echo "Run it with:"
echo "  open \"$TARGET_APP\""
