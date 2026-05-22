#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f scripts/version.sh ]]; then
  source scripts/version.sh
else
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

echo "Dosty Speak — macOS desktop release diagnostics"
echo "=============================================="
echo "Version: $DOSTY_SPEAK_VERSION"
echo

echo "Installed app:"
if [[ -d "$HOME/Applications/Dosty Speak.app" ]]; then
  echo "  OK: $HOME/Applications/Dosty Speak.app"
else
  echo "  MISSING: $HOME/Applications/Dosty Speak.app"
fi

echo
echo "dist contents:"
mkdir -p dist
find dist -maxdepth 1 -type f -print | sed 's/^/  /' || true

echo
echo "Expected desktop release files:"
echo "  dist/DostySpeak-macOS-$DOSTY_SPEAK_VERSION.zip"
echo "  dist/DostySpeak-macOS-$DOSTY_SPEAK_VERSION.dmg"
