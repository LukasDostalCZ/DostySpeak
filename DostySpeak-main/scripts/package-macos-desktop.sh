#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -d "$HOME/Applications/Dosty Speak.app" ]]; then
  echo "Installed app missing. Building macOS desktop first..."
  chmod +x scripts/install-macos.sh
  ./scripts/install-macos.sh
  exit 0
fi

if [[ -f VERSION ]]; then
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION)"
else
  DOSTY_SPEAK_VERSION="0.0.0"
fi

DIST_DIR="dist"
APP="$HOME/Applications/Dosty Speak.app"
mkdir -p "$DIST_DIR"

ZIP_NAME="DostySpeak-macOS-$DOSTY_SPEAK_VERSION.zip"
DMG_NAME="DostySpeak-macOS-$DOSTY_SPEAK_VERSION.dmg"

rm -f "$DIST_DIR/$ZIP_NAME" "$DIST_DIR/$DMG_NAME"

echo "Creating desktop release ZIP:"
ditto -c -k --keepParent "$APP" "$DIST_DIR/$ZIP_NAME"

if command -v hdiutil >/dev/null 2>&1; then
  TMP_DMG_DIR="$(mktemp -d)"
  cp -R "$APP" "$TMP_DMG_DIR/"
  ln -s /Applications "$TMP_DMG_DIR/Applications" 2>/dev/null || true
  hdiutil create -volname "Dosty Speak $DOSTY_SPEAK_VERSION" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DIST_DIR/$DMG_NAME" >/dev/null
  rm -rf "$TMP_DMG_DIR"
fi

echo
echo "Created:"
find "$DIST_DIR" -maxdepth 1 \( -name "$ZIP_NAME" -o -name "$DMG_NAME" \) -print | sed 's/^/  /'
