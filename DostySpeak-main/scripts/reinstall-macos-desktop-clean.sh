#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Dosty Speak — clean macOS desktop reinstall"
echo "=========================================="
echo

echo "Closing any running Dosty Speak..."
pkill -x "Dosty Speak" 2>/dev/null || true
pkill -x "dosty-speak" 2>/dev/null || true
sleep 1

echo "Removing previous installed app and build folder..."
rm -rf "$HOME/Applications/Dosty Speak.app"
rm -rf build-macos

echo
echo "Building and installing again..."
chmod +x scripts/install-macos.sh
./scripts/install-macos.sh

echo
echo "Done."
echo "Run:"
echo "  open \"$HOME/Applications/Dosty Speak.app\""
