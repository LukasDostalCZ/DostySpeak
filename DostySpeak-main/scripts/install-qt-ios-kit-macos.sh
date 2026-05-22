#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

QT_VERSION="${QT_VERSION:-$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 6.11.1)}"
# App version and Qt version are not always the same. Prefer installed Qt version if known.
if [[ ! "$QT_VERSION" =~ ^6\. ]]; then
  QT_VERSION="6.11.1"
fi

QT_ROOT="${QT_ROOT:-$HOME/Qt}"
MAINTENANCE_TOOL="$QT_ROOT/MaintenanceTool.app/Contents/MacOS/MaintenanceTool"
QT_IOS_PREFIX="${QT_IOS_PREFIX:-}"

echo "Dosty Speak — Qt iOS kit installer/checker"
echo "=========================================="
echo

find_ios_kit() {
  find "$QT_ROOT" -maxdepth 4 -type d -name ios 2>/dev/null | while read -r candidate; do
    if [[ -f "$candidate/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
      echo "$candidate"
      return 0
    fi
  done | sort -V | tail -n 1
}

if [[ -n "$QT_IOS_PREFIX" && -f "$QT_IOS_PREFIX/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
  echo "Qt iOS kit already set:"
  echo "  $QT_IOS_PREFIX"
  exit 0
fi

FOUND="$(find_ios_kit || true)"
if [[ -n "$FOUND" ]]; then
  echo "Qt iOS kit found:"
  echo "  $FOUND"
  echo
  echo "Recommended export:"
  echo "  export QT_IOS_PREFIX=\"$FOUND\""
  exit 0
fi

echo "Qt iOS kit was not found under:"
echo "  $QT_ROOT"
echo

if [[ -x "$MAINTENANCE_TOOL" ]]; then
  echo "Qt Maintenance Tool found:"
  echo "  $MAINTENANCE_TOOL"
  echo
  echo "Trying command-line install first..."
  echo "If Qt asks for login or GUI confirmation, the script will open Maintenance Tool for you."
  echo

  # Qt IFW component names can differ by version. Try common patterns, but do not pretend this is guaranteed.
  set +e
  "$MAINTENANCE_TOOL" --checkupdates >/tmp/dosty-qt-maintenance-check.log 2>&1
  "$MAINTENANCE_TOOL" install "qt.qt6.${QT_VERSION}.ios" --confirm-command --accept-licenses --default-answer --email "${QT_ACCOUNT_EMAIL:-}" --pw "${QT_ACCOUNT_PASSWORD:-}" >/tmp/dosty-qt-ios-install.log 2>&1
  code=$?
  set -e

  FOUND="$(find_ios_kit || true)"
  if [[ -n "$FOUND" ]]; then
    echo "Qt iOS kit installed:"
    echo "  $FOUND"
    exit 0
  fi

  echo "Automatic command-line install did not complete."
  echo "This usually happens when Qt requires account login or the component id is different."
  echo
  echo "Opening Maintenance Tool now."
  echo "In the window choose:"
  echo "  Add or remove components"
  echo "Then enable:"
  echo "  Qt 6.x.x -> iOS"
  echo
  echo "After installation finishes, return to Terminal and press Enter."
  open "$QT_ROOT/MaintenanceTool.app" || true
  read -r -p "Press Enter after installing the Qt iOS component, or type q to stop: " answer
  if [[ "$answer" =~ ^[Qq]$ ]]; then
    exit 1
  fi

  FOUND="$(find_ios_kit || true)"
  if [[ -n "$FOUND" ]]; then
    echo "Qt iOS kit found:"
    echo "  $FOUND"
    exit 0
  fi

  echo "Qt iOS kit is still missing."
  echo "Open Maintenance Tool again and make sure the iOS component is selected."
  echo
  echo "Command-line logs:"
  echo "  /tmp/dosty-qt-maintenance-check.log"
  echo "  /tmp/dosty-qt-ios-install.log"
  exit 1
fi

echo "Qt Maintenance Tool was not found."
echo "I can download the Qt Online Installer, but Qt still may require interactive login."
echo

INSTALLER_DMG="$HOME/Downloads/qt-online-installer-macOS.dmg"
INSTALLER_URL="https://download.qt.io/official_releases/online_installers/qt-online-installer-macOS-x64-online.dmg"

ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  INSTALLER_URL="https://download.qt.io/official_releases/online_installers/qt-online-installer-macOS-arm64-online.dmg"
fi

echo "Downloading Qt Online Installer:"
echo "  $INSTALLER_URL"
echo "To:"
echo "  $INSTALLER_DMG"

curl -L "$INSTALLER_URL" -o "$INSTALLER_DMG"

echo
echo "Opening installer DMG..."
open "$INSTALLER_DMG"

echo
echo "Install Qt with these components:"
echo "  Qt 6.x.x -> macOS"
echo "  Qt 6.x.x -> iOS"
echo "  Qt 6.x.x -> Android arm64-v8a"
echo
echo "After installation finishes, run:"
echo "  ./scripts/prepare-ios-iphone.sh"
