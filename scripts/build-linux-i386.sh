#!/usr/bin/env bash
set -euo pipefail

echo "Dosty Speak - experimental 32-bit Linux build"
echo "Run this inside a real 32-bit i386 Debian/Ubuntu environment/container."
echo

sudo apt update
sudo apt install -y build-essential cmake ninja-build qtbase5-dev qtbase5-dev-tools python3 python3-venv espeak-ng alsa-utils

rm -rf build-i386
cmake -S . -B build-i386 -G Ninja -DCMAKE_BUILD_TYPE=MinSizeRel
cmake --build build-i386 -j"$(nproc)"

echo
echo "Built:"
echo "  build-i386/dosty-speak"
