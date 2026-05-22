#!/usr/bin/env bash
set -euo pipefail

echo "Dosty Speak — select full Xcode"
echo "==============================="
echo

if [[ ! -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  echo "Full Xcode is not installed."
  echo "Opening Mac App Store..."
  open "macappstore://itunes.apple.com/app/id497799835" || true
  exit 1
fi

echo "Current xcode-select:"
xcode-select -p 2>/dev/null || true
echo

echo "Switching to:"
echo "  /Applications/Xcode.app/Contents/Developer"
echo
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

echo "Accepting license / first launch if needed..."
sudo xcodebuild -license accept || true
sudo xcodebuild -runFirstLaunch || true

echo
echo "Done."
echo "Current xcode-select:"
xcode-select -p
