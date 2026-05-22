#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Dosty Speak — desktop CMake diagnostics"
echo "======================================="
echo

echo "VERSION:"
cat VERSION
echo

echo "First 20 lines of CMakeLists.txt:"
sed -n '1,20p' CMakeLists.txt
echo

echo "Configure test:"
rm -rf build-diagnose-desktop
cmake -S . -B build-diagnose-desktop -DCMAKE_BUILD_TYPE=Release
echo
echo "OK: desktop CMake configured."
