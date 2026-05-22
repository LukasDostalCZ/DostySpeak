#!/usr/bin/env bash
set -euo pipefail

APP="$HOME/Applications/Dosty Speak.app"
BIN="$APP/Contents/MacOS/dosty-speak"

if [[ ! -x "$BIN" ]]; then
  echo "Binary not found:"
  echo "  $BIN"
  exit 1
fi

echo "Running Dosty Speak from Terminal..."
echo "Binary:"
echo "  $BIN"
echo

"$BIN"
