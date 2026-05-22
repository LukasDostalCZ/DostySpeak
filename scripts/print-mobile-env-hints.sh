#!/usr/bin/env bash
set -euo pipefail

echo "Dosty Speak — mobile environment hints"
echo "======================================"

DEFAULT_ANDROID_SDK="$HOME/Library/Android/sdk"
FOUND_QT_ANDROID="$(find "$HOME/Qt" -maxdepth 3 -type d -name "android_arm64_v8a" 2>/dev/null | head -n1 || true)"
FOUND_QT_IOS="$(find "$HOME/Qt" -maxdepth 3 -type d -name "ios" 2>/dev/null | head -n1 || true)"

if [[ -d "$DEFAULT_ANDROID_SDK" ]]; then
  echo "export ANDROID_SDK_ROOT=\"$DEFAULT_ANDROID_SDK\""
  NDK="$(find "$DEFAULT_ANDROID_SDK/ndk" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -n1 || true)"
  if [[ -n "$NDK" ]]; then
    echo "export ANDROID_NDK_ROOT=\"$NDK\""
  fi
fi

if [[ -n "$FOUND_QT_ANDROID" ]]; then
  echo "export QT_ANDROID_PREFIX=\"$FOUND_QT_ANDROID\""
fi

if command -v brew >/dev/null 2>&1; then
  echo "export QT_HOST_PATH=\"$(brew --prefix qt)\""
fi

if [[ -n "$FOUND_QT_IOS" ]]; then
  echo "export QT_IOS_PREFIX=\"$FOUND_QT_IOS\""
fi
