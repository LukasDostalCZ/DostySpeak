#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f scripts/version.sh ]]; then
  source scripts/version.sh
else
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

find_qt_macos_prefix() {
  if [[ -n "${QT_MACOS_PREFIX:-}" && -f "$QT_MACOS_PREFIX/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
    echo "$QT_MACOS_PREFIX"
    return 0
  fi

  local official
  official="$(find "$HOME/Qt" -maxdepth 4 -type d -name "macos" 2>/dev/null | while read -r candidate; do
    if [[ -f "$candidate/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
      echo "$candidate"
      break
    fi
  done)"
  if [[ -n "$official" ]]; then
    echo "$official"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    brew --prefix qt
    return 0
  fi

  return 1
}


QT_PREFIX="${QT_PREFIX:-$(find_qt_macos_prefix)}"
export PATH="$QT_PREFIX/bin:$PATH"

APP="build-mobile-preview-macos/dosty-speak-mobile.app"
OUT_DIR="dist"
OUT_ZIP="$OUT_DIR/DostySpeak-MobilePreview-${DOSTY_SPEAK_VERSION}-macOS.zip"

if [[ ! -d "$APP" ]]; then
  echo "Build preview first:"
  echo "  ./scripts/build-mobile-preview-macos.sh"
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Creating mobile preview ZIP..."
echo "For development preview, this package includes the .app but the reliable launcher is still scripts/run-mobile-preview-macos.sh with Homebrew Qt."

# Try macdeployqt silently, but do not print optional module noise.
if command -v macdeployqt >/dev/null 2>&1; then
  macdeployqt "$APP" -qmldir=mobile/qml >/tmp/dosty-mobile-macdeployqt.log 2>&1 || true
fi

codesign --force --deep --sign - "$APP" >/tmp/dosty-mobile-codesign.log 2>&1 || true

rm -f "$OUT_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT_ZIP"

echo
echo "Created:"
echo "  $OUT_ZIP"
echo
echo "If the packaged app does not open on another Mac, build with official Qt macOS kit instead of Homebrew Qt."
