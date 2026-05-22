#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f scripts/version.sh ]]; then
  source scripts/version.sh
else
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

echo "Dosty Speak — mobile preview diagnostics"
echo "========================================"

QT_PREFIX="${QT_PREFIX:-}"
if [[ -z "$QT_PREFIX" ]]; then
  if [[ -n "${QT_MACOS_PREFIX:-}" ]]; then
    QT_PREFIX="$QT_MACOS_PREFIX"
  else
    QT_PREFIX="$(find "$HOME/Qt" -maxdepth 4 -type d -name "macos" 2>/dev/null | while read -r candidate; do
      if [[ -f "$candidate/lib/cmake/Qt6/Qt6Config.cmake" ]]; then echo "$candidate"; break; fi
    done)"
    if [[ -z "$QT_PREFIX" ]] && command -v brew >/dev/null 2>&1; then
      QT_PREFIX="$(brew --prefix qt)"
    fi
  fi
fi

APP="build-mobile-preview-macos/dosty-speak-mobile.app"
BIN="$APP/Contents/MacOS/dosty-speak-mobile"

echo "Qt prefix:"
echo "  ${QT_PREFIX:-not found}"
echo

if [[ ! -x "$BIN" ]]; then
  echo "Binary not found:"
  echo "  $BIN"
  echo "Run:"
  echo "  ./scripts/build-mobile-preview-macos.sh"
  exit 1
fi

echo "Linked frameworks:"
otool -L "$BIN" || true
echo

echo "QML import paths:"
echo "  $QT_PREFIX/qml"
echo

export DYLD_FRAMEWORK_PATH="$QT_PREFIX/lib:${DYLD_FRAMEWORK_PATH:-}"
export QML2_IMPORT_PATH="$QT_PREFIX/qml:${QML2_IMPORT_PATH:-}"
export QT_PLUGIN_PATH="$QT_PREFIX/plugins:${QT_PLUGIN_PATH:-}"
export QT_DEBUG_PLUGINS=1
export QML_IMPORT_TRACE=1

echo "Launching with full Qt debug logs..."
"$BIN"
