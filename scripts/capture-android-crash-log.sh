#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="${ANDROID_APP_ID:-cz.dosty.speak}"
OLD_APP_ID="org.qtproject.example.dosty_speak_mobile"
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
STAMP="$(date +%Y%m%d-%H%M%S)"
FULL_LOG="$LOG_DIR/dosty-speak-$VERSION-android-crash-$STAMP.log"
FILTERED_LOG="$LOG_DIR/dosty-speak-$VERSION-android-crash-$STAMP-filtered.log"

echo "Dosty Speak — Android crash log capture"
echo "======================================="
echo "App id:       $APP_ID"
echo "Old app id:   $OLD_APP_ID"
echo "Full log:     $FULL_LOG"
echo "Filtered log: $FILTERED_LOG"
echo

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is missing. Run dependency install from the builder first."
  exit 1
fi

echo "Connected devices:"
adb devices | tee "$FULL_LOG"
echo >> "$FULL_LOG"

if ! adb devices | awk 'NR>1 && $2=="device" {found=1} END {exit !found}'; then
  echo
  echo "No authorized Android device found."
  echo "Enable USB debugging, reconnect the phone and accept the RSA dialog."
  exit 1
fi

APK="$(find dist/android -maxdepth 1 -name 'DostySpeak-Mobile-*-debug-signed.apk' -print 2>/dev/null | sort -V | tail -n 1 || true)"
if [[ -n "$APK" ]]; then
  echo
  echo "Latest signed APK:"
  echo "  $APK"
  read -r -p "Clean install this APK before logging? [Y/n]: " install_choice
  install_choice="${install_choice:-Y}"
  if [[ "$install_choice" =~ ^[Yy]$ ]]; then
    adb uninstall "$OLD_APP_ID" >/dev/null 2>&1 || true
    adb uninstall "$APP_ID" >/dev/null 2>&1 || true
    adb install -r "$APK" | tee -a "$FULL_LOG" || true
  fi
fi

echo
echo "Clearing old logcat..."
adb logcat -c || true

echo "Starting app..."
adb shell am start -n "$APP_ID/org.qtproject.qt.android.bindings.QtActivity" | tee -a "$FULL_LOG" || \
  adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 | tee -a "$FULL_LOG" || true

echo
echo "Capturing logcat for 35 seconds. Reproduce the crash now."
TMP_LOG="$(mktemp)"
# Do not stream logcat forever. Some adb/logcat combinations ignore TERM,
# which made the helper look frozen. We sleep first and then dump collected logs.
sleep 35
adb logcat -v time -d > "$TMP_LOG" 2>&1 || true

cat "$TMP_LOG" >> "$FULL_LOG"
grep -iE "FATAL EXCEPTION|AndroidRuntime|Dosty|dosty|Qt|QtLoader|QQml|QML|libdosty|cz\.dosty|org\.qtproject\.example\.dosty|main library|SIGSEGV|signal|backtrace|Exception|error" "$TMP_LOG" > "$FILTERED_LOG" || true
rm -f "$TMP_LOG"

echo
echo "Saved full log:"
echo "  $FULL_LOG"
echo "Saved filtered log:"
echo "  $FILTERED_LOG"
echo
echo "Send me the filtered log first."
