#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"

echo "Dosty Speak — macOS dist verifier"
echo "================================="
echo "Version: $VERSION"
echo

ok=1
for f in "dist/DostySpeak-macOS-$VERSION.zip" "dist/DostySpeak-macOS-$VERSION.dmg"; do
  if [[ -s "$f" ]]; then
    echo "OK: $f"
  else
    echo "MISSING: $f"
    ok=0
  fi
done

echo
echo "dist contents:"
find dist -maxdepth 2 -type f -print 2>/dev/null | sed 's/^/  /' || true

[[ "$ok" == "1" ]] || exit 1
