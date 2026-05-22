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


rm -rf build-mobile-preview-macos

echo "Dosty Speak — build mobile preview on macOS"
echo "==========================================="

QT_PREFIX="${QT_PREFIX:-$(find_qt_macos_prefix)}"
export PATH="$QT_PREFIX/bin:$PATH"

BUILD_DIR="build-mobile-preview-macos"
APP="$BUILD_DIR/dosty-speak-mobile.app"
BIN="$APP/Contents/MacOS/dosty-speak-mobile"

rm -rf "$BUILD_DIR"

cmake -S mobile -B "$BUILD_DIR" \
  -G Ninja \
  -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
  -DCMAKE_BUILD_TYPE=Release

cmake --build "$BUILD_DIR" --parallel

echo
echo "Built:"
echo "  $APP"

echo
echo "Testing direct launch with Qt runtime paths..."
export DYLD_FRAMEWORK_PATH="$QT_PREFIX/lib:${DYLD_FRAMEWORK_PATH:-}"
export QML2_IMPORT_PATH="$QT_PREFIX/qml:${QML2_IMPORT_PATH:-}"
export QT_PLUGIN_PATH="$QT_PREFIX/plugins:${QT_PLUGIN_PATH:-}"

if [[ ! -x "$BIN" ]]; then
  echo "Error: binary not found:"
  echo "  $BIN"
  exit 1
fi

echo
echo "Run with logs:"
echo "  ./scripts/run-mobile-preview-macos.sh"
echo
echo "Normal macOS open may still fail with Homebrew Qt. For preview use the run script above."
