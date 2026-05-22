#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:-both}"
BUILD_DIR="${BUILD_DIR:-build-linux}"
DIST_DIR="${DIST_DIR:-dist/linux}"

if [[ -f scripts/version.sh ]]; then
  # shellcheck source=/dev/null
  source scripts/version.sh
  VERSION="$DOSTY_SPEAK_VERSION"
else
  VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

mkdir -p "$DIST_DIR"

say() {
  printf '\n%s\n' "$1"
  printf '%*s\n' "${#1}" '' | tr ' ' '='
}

warn() { printf 'Warning: %s\n' "$*" >&2; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Missing required tool: $1"; }

print_dependency_hints() {
  cat <<'EOT'
Dependency hints:
  Debian/Ubuntu:
    sudo apt update
    sudo apt install build-essential cmake ninja-build qt6-base-dev qt6-base-dev-tools espeak-ng alsa-utils rpm

  Fedora:
    sudo dnf install gcc-c++ cmake ninja-build qt6-qtbase-devel espeak-ng alsa-utils rpm-build

  openSUSE:
    sudo zypper install gcc-c++ cmake ninja qt6-base-devel espeak-ng alsa-utils rpm-build

  Arch:
    sudo pacman -S --needed base-devel cmake ninja qt6-base espeak-ng alsa-utils rpm-tools
EOT
}

check_basic_tools() {
  local missing=()
  for tool in cmake; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'Missing tools: %s\n' "${missing[*]}" >&2
    print_dependency_hints
    exit 1
  fi
}

configure_build() {
  say "Configuring Linux build"
  local generator_args=()
  if command -v ninja >/dev/null 2>&1; then
    generator_args=(-G Ninja)
  else
    warn "ninja not found, using CMake default generator."
  fi

  cmake -S . -B "$BUILD_DIR" "${generator_args[@]}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCPACK_PACKAGE_FILE_NAME="DostySpeak-${VERSION}-linux-$(uname -m)"
}

build_app() {
  check_basic_tools
  configure_build
  say "Building Linux desktop app"
  cmake --build "$BUILD_DIR" --parallel "$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
}

copy_packages() {
  local extension="$1"
  shopt -s nullglob
  local files=("$BUILD_DIR"/*."$extension" ./*."$extension")
  if (( ${#files[@]} == 0 )); then
    fail "No .$extension package was created."
  fi
  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    cp -f "$file" "$DIST_DIR/"
    printf 'Created: %s\n' "$DIST_DIR/$(basename "$file")"
  done
}

package_deb() {
  build_app
  say "Creating DEB package"
  (cd "$BUILD_DIR" && cpack -G DEB)
  copy_packages deb
}

package_rpm() {
  need rpmbuild
  build_app
  say "Creating RPM package"
  (cd "$BUILD_DIR" && cpack -G RPM)
  copy_packages rpm
}

clean_linux() {
  say "Cleaning Linux build output"
  rm -rf build-linux build-linux-x86_64 build-linux-i386 dist/linux
  mkdir -p dist/linux
  printf 'Cleaned Linux build directories.\n'
}

case "$MODE" in
  app|build)
    build_app
    ;;
  deb)
    package_deb
    ;;
  rpm)
    package_rpm
    ;;
  both|all)
    package_deb
    package_rpm
    ;;
  clean)
    clean_linux
    ;;
  *)
    cat >&2 <<EOT
Usage:
  $0 app
  $0 deb
  $0 rpm
  $0 both
  $0 clean
EOT
    exit 2
    ;;
esac
