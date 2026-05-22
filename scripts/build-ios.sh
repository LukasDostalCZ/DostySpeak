#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f scripts/version.sh ]]; then
  # shellcheck source=/dev/null
  source scripts/version.sh
else
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

echo "Dosty Speak — iOS builder"
echo "========================="
echo "Version: $DOSTY_SPEAK_VERSION"
echo

valid_qt_ios_prefix() {
  local path="$1"
  [[ -n "$path" ]] || return 1
  [[ -f "$path/lib/cmake/Qt6/Qt6Config.cmake" ]] || return 1
  [[ -f "$path/lib/cmake/Qt6/qt.toolchain.cmake" ]] || return 1
  [[ "$path" == *ios* ]] || return 1
}

find_qt_ios() {
  if [[ -n "${QT_IOS_PREFIX:-}" ]] && valid_qt_ios_prefix "$QT_IOS_PREFIX"; then
    echo "$QT_IOS_PREFIX"
    return 0
  fi

  find "$HOME/Qt" -maxdepth 4 -type d -name "ios" 2>/dev/null | while read -r candidate; do
    if valid_qt_ios_prefix "$candidate"; then
      echo "$candidate"
      break
    fi
  done
}

manual_ios_help() {
  echo
  echo "Manual iOS step required:"
  echo
  echo "1) Open Xcode once."
  echo "2) Accept the license and finish first launch."
  echo "3) If Terminal still points to Command Line Tools, run:"
  echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "4) For real device/iPhone build, set your Apple Team ID:"
  echo "   export APPLE_DEVELOPMENT_TEAM=\"YOURTEAMID\""
  echo
  echo "Without APPLE_DEVELOPMENT_TEAM the script will only generate the Xcode project,"
  echo "because xcodebuild cannot sign the app automatically."
  echo
}

check_full_xcode_selected() {
  if [[ ! -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    echo "Full Xcode is missing."
    open "macappstore://itunes.apple.com/app/id497799835" || true
    manual_ios_help
    return 1
  fi

  local current_dev
  current_dev="$(xcode-select -p 2>/dev/null || true)"

  if [[ "$current_dev" != "/Applications/Xcode.app/Contents/Developer" ]]; then
    echo "xcode-select currently points to:"
    echo "  ${current_dev:-not set}"
    echo
    echo "The builder will not run sudo in the animated build overlay, because password"
    echo "input gets hidden or broken there."
    manual_ios_help
    return 2
  fi

  return 0
}

find_iphoneos_sdk_path() {
  xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true
}

check_full_xcode_selected

QT_IOS_PREFIX="$(find_qt_ios || true)"
if [[ -z "$QT_IOS_PREFIX" ]] || ! valid_qt_ios_prefix "$QT_IOS_PREFIX"; then
  echo "Missing or invalid Qt iOS kit."
  manual_ios_help
  exit 1
fi

IPHONEOS_SDK_PATH="$(find_iphoneos_sdk_path)"
if [[ -z "$IPHONEOS_SDK_PATH" || ! -d "$IPHONEOS_SDK_PATH" ]]; then
  echo "iPhoneOS SDK was not found through xcrun."
  manual_ios_help
  exit 1
fi

BUILD_DIR="build-ios"

echo
echo "Using:"
echo "  Qt iOS:       $QT_IOS_PREFIX"
echo "  Xcode:        $(xcode-select -p)"
echo "  iPhoneOS SDK: $IPHONEOS_SDK_PATH"
if [[ -n "${APPLE_DEVELOPMENT_TEAM:-}" ]]; then
  echo "  Apple Team:   $APPLE_DEVELOPMENT_TEAM"
else
  echo "  Apple Team:   not set"
fi
echo

rm -rf "$BUILD_DIR"

cmake -S mobile -B "$BUILD_DIR" \
  -G Xcode \
  -DCMAKE_PREFIX_PATH="$QT_IOS_PREFIX" \
  -DQt6_DIR="$QT_IOS_PREFIX/lib/cmake/Qt6" \
  -DCMAKE_TOOLCHAIN_FILE="$QT_IOS_PREFIX/lib/cmake/Qt6/qt.toolchain.cmake" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="$IPHONEOS_SDK_PATH" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS=iphoneos \
  -DCMAKE_XCODE_ATTRIBUTE_SDKROOT=iphoneos \
  -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="${APPLE_DEVELOPMENT_TEAM:-}" \
  -DCMAKE_BUILD_TYPE=Release

echo
echo "Generated Xcode project:"
find "$BUILD_DIR" -maxdepth 2 -name "*.xcodeproj" -print | sed 's/^/  /'

VALID_PROJECT="$(find "$BUILD_DIR" -maxdepth 2 -name "*.xcodeproj" -type d 2>/dev/null | while IFS= read -r project; do
  if [[ -f "$project/project.pbxproj" ]]; then
    echo "$project"
    break
  fi
done)"

if [[ -z "$VALID_PROJECT" ]]; then
  echo
  echo "CMake finished, but no valid Xcode project.pbxproj was created."
  echo "Removing stale build-ios folder so Xcode will not open a broken project."
  rm -rf "$BUILD_DIR"
  exit 1
fi

if [[ -z "${APPLE_DEVELOPMENT_TEAM:-}" ]]; then
  echo
  echo "Skipping xcodebuild compile because APPLE_DEVELOPMENT_TEAM is not set."
  echo "This is expected. iOS signing requires a development team."
  echo
  echo "Open the project in Xcode, select your Team in Signing & Capabilities,"
  echo "or export APPLE_DEVELOPMENT_TEAM and run this script again."
  echo
  exit 0
fi

cmake --build "$BUILD_DIR" --config Release

echo
echo "iOS build finished."
