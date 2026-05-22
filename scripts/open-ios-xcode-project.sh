#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="build-ios/DostySpeakMobile.xcodeproj"
if [[ ! -d "$PROJECT" ]]; then
  echo "Xcode project is missing. Generating it first..."
  chmod +x scripts/prepare-ios-iphone.sh
  ./scripts/prepare-ios-iphone.sh
  exit 0
fi

open "$PROJECT"
