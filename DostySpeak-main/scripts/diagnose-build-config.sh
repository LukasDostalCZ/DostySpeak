#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f scripts/version.sh ]]; then
  source scripts/version.sh
else
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

echo "Dosty Speak — build config diagnostics"
echo "======================================"
echo

echo "VERSION:"
cat VERSION
echo

echo "Root CMake project line:"
grep -nE 'file\(STRINGS|project\(' CMakeLists.txt | head -n 8
echo

echo "Mobile CMake project line:"
grep -nE 'file\(STRINGS|project\(' mobile/CMakeLists.txt | head -n 8
echo

echo "CMake configure test:"
rm -rf build-diagnose
cmake -S . -B build-diagnose -DCMAKE_BUILD_TYPE=Release
echo
echo "OK: root project configures."
