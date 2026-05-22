#!/usr/bin/env bash
set -euo pipefail

rm -rf "$HOME/Library/Application Support/Dosty/DostySpeak"
rm -rf "$HOME/Library/Preferences/cz.dosty.speak.plist"
rm -rf "$HOME/.local/share/Dosty/DostySpeak"

echo "Dosty Speak data removed."
