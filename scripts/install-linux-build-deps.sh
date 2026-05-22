#!/usr/bin/env bash
set -euo pipefail

if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y build-essential cmake ninja-build qt6-base-dev qtbase5-dev qtbase5-dev-tools espeak-ng alsa-utils rpm
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y gcc-c++ cmake ninja-build qt6-qtbase-devel qt5-qtbase-devel espeak-ng alsa-utils rpm-build
elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y gcc-c++ cmake ninja qt6-base-devel libqt5-qtbase-devel espeak-ng alsa-utils rpm-build
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed base-devel cmake ninja qt6-base qt5-base espeak-ng alsa-utils rpm-tools
else
    echo "Unknown package manager. Install dependencies manually."
    exit 1
fi
