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

  if [[ -n "${QT_HOST_PATH:-}" && -f "$QT_HOST_PATH/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
    echo "$QT_HOST_PATH"
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
APP="build-mobile-preview-macos/dosty-speak-mobile.app"
BIN="$APP/Contents/MacOS/dosty-speak-mobile"

if [[ ! -x "$BIN" ]]; then
  echo "Mobile preview is not built yet."
  echo "Build it from the terminal builder first:"
  echo "  Build mobile preview for this Mac"
  exit 1
fi

export DYLD_FRAMEWORK_PATH="$QT_PREFIX/lib:${DYLD_FRAMEWORK_PATH:-}"
export QML2_IMPORT_PATH="$QT_PREFIX/qml:${QML2_IMPORT_PATH:-}"
export QT_PLUGIN_PATH="$QT_PREFIX/plugins:${QT_PLUGIN_PATH:-}"
export QML_IMPORT_TRACE="${QML_IMPORT_TRACE:-0}"

if [[ "${DOSTY_DEBUG_QT:-0}" == "1" ]]; then
  export QT_DEBUG_PLUGINS=1
  export DYLD_PRINT_RPATHS=1
fi

echo "Launching mobile preview:"
echo "  $BIN"
echo
echo "Qt:"
echo "  $QT_PREFIX"
echo

# Default behavior: launch and return immediately so the terminal builder does not look frozen.
# For debugging, use:
#   DOSTY_WAIT_MOBILE_PREVIEW=1 ./scripts/run-mobile-preview-macos.sh
if [[ "${DOSTY_WAIT_MOBILE_PREVIEW:-0}" == "1" ]]; then
  exec "$BIN"
else
  "$BIN" >/tmp/dosty-speak-mobile-preview.log 2>&1 &
  pid=$!
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    echo "Mobile preview is running in background."
    echo "PID: $pid"
    echo "Runtime log:"
    echo "  /tmp/dosty-speak-mobile-preview.log"
    exit 0
  else
    echo "Mobile preview closed immediately."
    echo "Last log lines:"
    tail -n 80 /tmp/dosty-speak-mobile-preview.log 2>/dev/null || true
    exit 1
  fi
fi
