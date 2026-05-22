#!/usr/bin/env bash
set -euo pipefail

APP_SUPPORT="$HOME/Library/Application Support/Dosty/DostySpeak"
PREFS1="$HOME/Library/Preferences/cz.dosty.dostyspeak.plist"
PREFS2="$HOME/Library/Preferences/Dosty Speak.plist"

echo "Closing Dosty Speak..."
pkill -x "Dosty Speak" 2>/dev/null || true
pkill -x "dosty-speak" 2>/dev/null || true

echo "Removing app settings and local data:"
echo "  $APP_SUPPORT"
rm -rf "$APP_SUPPORT"

rm -f "$PREFS1" "$PREFS2"

echo "Done. Next launch will show the first-run wizard again."
echo "Run:"
echo '  open "$HOME/Applications/Dosty Speak.app"'
