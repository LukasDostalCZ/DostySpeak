#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"

say() { printf '%s\n' "$*"; }
fail() { say "$*"; exit 1; }

find_valid_xcode_project() {
  local root="${1:-build-ios}"
  find "$root" -maxdepth 3 -name "*.xcodeproj" -type d 2>/dev/null | while IFS= read -r project; do
    if [[ -f "$project/project.pbxproj" ]]; then
      printf '%s\n' "$project"
      return 0
    fi
  done
}

say "Dosty Speak — iPhone preparation"
say "================================"
say "Version: $VERSION"
say

if ! command -v xcodebuild >/dev/null 2>&1; then
  say "Full Xcode is required."
  say "Opening Xcode in the App Store..."
  open "macappstore://apps.apple.com/app/xcode/id497799835" || true
  say
  say "Install Xcode, open it once, then run:"
  say "  sudo xcodebuild -license accept"
  say "  sudo xcodebuild -runFirstLaunch"
  exit 1
fi

if [[ "$(xcode-select -p 2>/dev/null || true)" != *"Xcode.app"* ]]; then
  say "xcode-select does not point to full Xcode."
  say "Switching to /Applications/Xcode.app/Contents/Developer"
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
fi

say "Checking Qt iOS kit..."
chmod +x scripts/install-qt-ios-kit-macos.sh
./scripts/install-qt-ios-kit-macos.sh

QT_IOS_PREFIX="${QT_IOS_PREFIX:-}"
if [[ -z "$QT_IOS_PREFIX" ]]; then
  QT_IOS_PREFIX="$(find "$HOME/Qt" -maxdepth 4 -type d -name ios 2>/dev/null | while IFS= read -r candidate; do
    if [[ -f "$candidate/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
      echo "$candidate"
    fi
  done | sort -V | tail -n 1)"
fi

if [[ -z "$QT_IOS_PREFIX" || ! -f "$QT_IOS_PREFIX/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
  say "Qt iOS kit is still missing."
  say "Install it through Qt Maintenance Tool and run this script again."
  exit 1
fi

say
say "Using Qt iOS:"
say "  $QT_IOS_PREFIX"
say

say "Cleaning old/stale iOS build folder..."
rm -rf build-ios

say "Generating Xcode project..."
chmod +x scripts/build-ios.sh
QT_IOS_PREFIX="$QT_IOS_PREFIX" ./scripts/build-ios.sh

PROJECT="$(find_valid_xcode_project build-ios | head -n 1 || true)"
if [[ -z "$PROJECT" ]]; then
  say
  say "Xcode project was not generated correctly."
  say "Expected a .xcodeproj folder containing project.pbxproj."
  say
  say "Found these project folders:"
  find build-ios -maxdepth 3 -name "*.xcodeproj" -type d -print 2>/dev/null | sed 's/^/  /' || true
  say
  say "Useful diagnostics:"
  say "  ./scripts/diagnose-ios-build-env.sh"
  exit 1
fi

say
say "Generated valid Xcode project:"
say "  $PROJECT"
say

say "Opening project in Xcode..."
open "$PROJECT"

say
say "Next steps in Xcode:"
say "1) Select target: dosty-speak-mobile"
say "2) Open Signing & Capabilities"
say "3) Team: choose your Apple ID/team"
say "4) Connect iPhone by cable and unlock it"
say "5) Select your iPhone as Run Destination"
say "6) Press Run"
say

if [[ -n "${APPLE_DEVELOPMENT_TEAM:-}" ]]; then
  say "APPLE_DEVELOPMENT_TEAM is set, also trying terminal build:"
  say "  $APPLE_DEVELOPMENT_TEAM"
  xcodebuild \
    -project "$PROJECT" \
    -scheme dosty-speak-mobile \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    DEVELOPMENT_TEAM="$APPLE_DEVELOPMENT_TEAM" \
    CODE_SIGN_STYLE=Automatic \
    build
fi
