#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:-release}"
BUILD_DIR="${BUILD_DIR:-build-linux}"
DIST_DIR="${DIST_DIR:-dist}"

if [[ -f scripts/version.sh ]]; then
  # shellcheck source=/dev/null
  source scripts/version.sh
  VERSION="$DOSTY_SPEAK_VERSION"
else
  VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

mkdir -p "$DIST_DIR"

host_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'x86_64' ;;
    i386|i486|i586|i686) printf 'i386' ;;
    aarch64|arm64) printf 'arm64' ;;
    *) uname -m ;;
  esac
}

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
    sudo apt install build-essential cmake ninja-build qt6-base-dev qt6-base-dev-tools qtbase5-dev qtbase5-dev-tools espeak-ng alsa-utils rpm

  Fedora:
    sudo dnf install gcc-c++ cmake ninja-build qt6-qtbase-devel qt5-qtbase-devel espeak-ng alsa-utils rpm-build

  openSUSE:
    sudo zypper install gcc-c++ cmake ninja qt6-base-devel libqt5-qtbase-devel espeak-ng alsa-utils rpm-build

  Arch:
    sudo pacman -S --needed base-devel cmake ninja qt6-base qt5-base espeak-ng alsa-utils rpm-tools
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
  local arch
  arch="$(host_arch)"
  local generator_args=()
  if command -v ninja >/dev/null 2>&1; then
    generator_args=(-G Ninja)
  else
    warn "ninja not found, using CMake default generator."
  fi

  cmake -S . -B "$BUILD_DIR" "${generator_args[@]}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCPACK_PACKAGE_FILE_NAME="DostySpeak-${VERSION}-linux-${arch}"
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
  local files=("$BUILD_DIR"/*."$extension")
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

package_all() {
  build_app
  say "Creating DEB package"
  (cd "$BUILD_DIR" && cpack -G DEB)
  copy_packages deb

  if command -v rpmbuild >/dev/null 2>&1; then
    say "Creating RPM package"
    (cd "$BUILD_DIR" && cpack -G RPM)
    copy_packages rpm
  else
    warn "rpmbuild not found, skipping RPM package."
  fi
}

create_portable_archive() {
  local arch portable_dir archive_name
  arch="$(host_arch)"
  portable_dir="$DIST_DIR/DostySpeak-Linux-$arch"
  archive_name="$DIST_DIR/DostySpeak-Linux-$arch.tar.gz"

  say "Creating portable Linux archive"
  rm -rf "$portable_dir" "$archive_name"
  mkdir -p "$portable_dir"
  cp "$BUILD_DIR/dosty-speak" "$portable_dir/"
  cp -r resources "$portable_dir/"
  cat > "$portable_dir/run-dosty-speak.sh" <<'RUN'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
./dosty-speak
RUN
  chmod +x "$portable_dir/run-dosty-speak.sh"
  tar -C "$DIST_DIR" -czf "$archive_name" "DostySpeak-Linux-$arch"
  printf 'Created: %s\n' "$archive_name"
}

portable_current() {
  build_app
  create_portable_archive
}

release_current() {
  build_app
  create_portable_archive
  say "Creating DEB package"
  (cd "$BUILD_DIR" && cpack -G DEB)
  copy_packages deb

  if command -v rpmbuild >/dev/null 2>&1; then
    say "Creating RPM package"
    (cd "$BUILD_DIR" && cpack -G RPM)
    copy_packages rpm
  else
    warn "rpmbuild not found, skipping RPM package."
  fi
}

release_i386() {
  local machine
  machine="$(uname -m)"
  if [[ "$machine" != "i386" && "$machine" != "i486" && "$machine" != "i586" && "$machine" != "i686" ]]; then
    fail "32-bit Linux release must be run inside a real i386/i686 Linux chroot, container or VM. Current machine: $machine"
  fi

  BUILD_DIR="build-linux-i386"
  release_current
}

clean_linux() {
  say "Cleaning Linux build output"
  rm -rf build-linux build-linux-x86_64 build-linux-i386 dist/linux
  rm -rf dist/DostySpeak-Linux-*
  rm -f dist/DostySpeak-*-linux-*.deb dist/DostySpeak-*-linux-*.rpm
  mkdir -p dist
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
    package_all
    ;;
  portable|tar|tar.gz)
    portable_current
    ;;
  release|current-release)
    release_current
    ;;
  i386|release-i386|linux-i386)
    release_i386
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
  $0 portable
  $0 release
  $0 release-i386
  $0 clean
EOT
    exit 2
    ;;
esac
