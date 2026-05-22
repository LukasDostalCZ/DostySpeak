#!/usr/bin/env bash
set -euo pipefail

echo "Dosty Speak — Android logcat helper"
echo "==================================="
echo
echo "Connect phone with USB debugging enabled, then reproduce the crash."
echo "Press Ctrl+C to stop."
echo

adb logcat -c || true
adb logcat | grep -iE "Dosty|dosty|Qt|AndroidRuntime|FATAL EXCEPTION|QQml|libdosty|cz\.dosty"
