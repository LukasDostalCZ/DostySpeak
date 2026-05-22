#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Dosty Speak — iOS build diagnostics"
echo "==================================="
echo

echo "VERSION:"
cat VERSION
echo

echo "xcode-select:"
xcode-select -p 2>/dev/null || true
echo

echo "xcodebuild version:"
xcodebuild -version 2>/dev/null || true
echo

echo "iphoneos SDK path:"
xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true
echo

echo "Available iOS SDKs:"
xcodebuild -showsdks 2>/dev/null | grep -i iphone || true
echo

echo "Qt iOS kits under ~/Qt:"
find "$HOME/Qt" -maxdepth 4 -type f -path "*/ios/lib/cmake/Qt6/Qt6Config.cmake" 2>/dev/null | sed 's#/lib/cmake/Qt6/Qt6Config.cmake##' || true
echo
