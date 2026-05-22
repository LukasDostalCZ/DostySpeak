#!/usr/bin/env bash
set -euo pipefail

echo "Dosty Speak — Linux installer"
echo "============================="

if command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y build-essential cmake qt6-base-dev qt6-base-dev-tools python3 python3-venv espeak-ng alsa-utils || \
  sudo apt install -y build-essential cmake qtbase5-dev qtbase5-dev-tools python3 python3-venv espeak-ng alsa-utils
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y gcc-c++ cmake qt6-qtbase-devel python3 espeak-ng alsa-utils
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed base-devel cmake qt6-base python espeak-ng alsa-utils
else
  echo "Unsupported package manager. Install CMake, Qt, Python 3, espeak-ng and alsa-utils manually."
fi

cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build -j"$(nproc)"
cmake --install build

echo
echo "Installed. Run:"
echo "  dosty-speak"
echo
echo "If it is not in your app menu yet, log out/in or run:"
echo "  update-desktop-database ~/.local/share/applications 2>/dev/null || true"
