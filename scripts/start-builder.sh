#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

case "$(uname -s)" in
  Darwin)
    chmod +x scripts/build-terminal-macos.sh
    exec scripts/build-terminal-macos.sh
    ;;
  Linux)
    chmod +x scripts/build-terminal-linux.sh
    exec scripts/build-terminal-linux.sh
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "On Windows, run from PowerShell:"
    echo "  powershell -ExecutionPolicy Bypass -File .\\scripts\\build-terminal-windows.ps1"
    ;;
  *)
    echo "Unsupported OS. Use the platform-specific builder in scripts/."
    exit 1
    ;;
esac
