#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="${ANDROID_APP_ID:-cz.dosty.speak}"
OLD_APP_ID="org.qtproject.example.dosty_speak_mobile"

echo "Dosty Speak — Android install helper"
echo "===================================="
echo

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is missing."
  exit 1
fi

APK="$(find dist/android -maxdepth 1 -name 'DostySpeak-Mobile-*-debug-signed.apk' -print 2>/dev/null | sort -V | tail -n 1 || true)"
if [[ -z "$APK" ]]; then
  echo "No signed APK found in dist/android. Build Android APK first."
  exit 1
fi

echo "Cleaning old package ids if present:"
echo "  $APP_ID"
echo "  $OLD_APP_ID"
adb uninstall "$OLD_APP_ID" >/dev/null 2>&1 || true
adb uninstall "$APP_ID" >/dev/null 2>&1 || true

echo
echo "Installing:"
echo "  $APK"
adb install -r "$APK"

echo
echo "Launching:"
adb shell am start -n "$APP_ID/org.qtproject.qt.android.bindings.QtActivity" || \
  adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1
