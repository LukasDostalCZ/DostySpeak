#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p cmake scripts dist/linux logs
chmod +x scripts/build-terminal-linux.sh scripts/build-linux-packages.sh 2>/dev/null || true

if [[ ! -f CMakeLists.txt ]]; then
  echo "CMakeLists.txt not found. Run this from the Dosty Speak repository root." >&2
  exit 1
fi

if ! grep -q 'cmake/DostyPackaging.cmake' CMakeLists.txt; then
  cat >> CMakeLists.txt <<'EOT'

# Linux DEB/RPM packaging.
if(UNIX AND NOT APPLE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/DostyPackaging.cmake")
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/DostyPackaging.cmake")
endif()
EOT
  echo "Patched CMakeLists.txt to include cmake/DostyPackaging.cmake"
else
  echo "CMakeLists.txt already includes cmake/DostyPackaging.cmake"
fi

echo "Linux packaging files are ready."
echo "Next:"
echo "  git status"
echo "  git diff"
echo "  git add CMakeLists.txt VERSION cmake/DostyPackaging.cmake scripts/build-terminal-linux.sh scripts/build-linux-packages.sh scripts/apply-linux-packaging-fix.sh docs/TUI-RUN-INSTRUCTIONS.md README-COMMIT.md"
