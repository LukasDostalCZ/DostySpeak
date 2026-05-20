#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

ask_yes_no() {
    local question="$1"
    local default="$2"
    local suffix answer

    if [[ "$default" == "y" ]]; then
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi

    while true; do
        read -r -p "$question $suffix: " answer
        if [[ -z "$answer" ]]; then
            [[ "$default" == "y" ]] && return 0 || return 1
        fi

        case "${answer,,}" in
            y|yes|a|ano) return 0 ;;
            n|no|ne) return 1 ;;
            *) echo "Please answer y/n, or press Enter for the default." ;;
        esac
    done
}

section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then echo "apt"; return; fi
    if command -v dnf >/dev/null 2>&1; then echo "dnf"; return; fi
    if command -v zypper >/dev/null 2>&1; then echo "zypper"; return; fi
    if command -v pacman >/dev/null 2>&1; then echo "pacman"; return; fi
    echo "unknown"
}

install_missing_tools() {
    local pm="$1"

    section "Installing missing build dependencies"

    case "$pm" in
        apt)
            sudo apt update
            sudo apt install -y build-essential cmake ninja-build qt6-base-dev qtbase5-dev qtbase5-dev-tools espeak-ng alsa-utils rpm
            ;;
        dnf)
            sudo dnf install -y gcc-c++ cmake ninja-build qt6-qtbase-devel qt5-qtbase-devel espeak-ng alsa-utils rpm-build
            ;;
        zypper)
            sudo zypper install -y gcc-c++ cmake ninja qt6-base-devel libqt5-qtbase-devel espeak-ng alsa-utils rpm-build
            ;;
        pacman)
            sudo pacman -S --needed base-devel cmake ninja qt6-base qt5-base espeak-ng alsa-utils rpm-tools
            ;;
        *)
            echo "Unknown package manager. Please install dependencies manually."
            echo
            echo "Debian/Ubuntu:"
            echo "  sudo apt install build-essential cmake ninja-build qt6-base-dev qtbase5-dev qtbase5-dev-tools espeak-ng alsa-utils rpm"
            echo
            echo "Fedora:"
            echo "  sudo dnf install gcc-c++ cmake ninja-build qt6-qtbase-devel qt5-qtbase-devel espeak-ng alsa-utils rpm-build"
            exit 1
            ;;
    esac
}

check_tools() {
    local missing=()
    local required_tools=(cmake ninja g++ cpack)

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing tools: ${missing[*]}"
        echo
        local pm
        pm="$(detect_package_manager)"
        echo "Detected package manager: $pm"
        echo

        if ask_yes_no "Install missing build dependencies now? This uses sudo." y; then
            install_missing_tools "$pm"
        else
            echo
            echo "Install manually and run this builder again."
            echo
            echo "Debian/Ubuntu:"
            echo "  sudo apt install build-essential cmake ninja-build qt6-base-dev qtbase5-dev qtbase5-dev-tools espeak-ng alsa-utils rpm"
            echo
            echo "Fedora:"
            echo "  sudo dnf install gcc-c++ cmake ninja-build qt6-qtbase-devel qt5-qtbase-devel espeak-ng alsa-utils rpm-build"
            exit 1
        fi
    fi

    # Re-check after optional installation.
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "Still missing after install attempt: $tool"
            exit 1
        fi
    done
}

get_project_version() {
    grep -E "VERSION [0-9]+\\.[0-9]+\\.[0-9]+" CMakeLists.txt | head -n1 | sed -E 's/.*VERSION ([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/'
}

echo "Dosty Speak - Linux release builder"
echo
echo "This script builds Linux artifacts and prints the full build log."
echo
echo "Targets:"
echo "  1) x86_64 / amd64 - main Qt app on the current 64-bit Linux"
echo "  2) i386 / 32-bit  - run this inside a real 32-bit Linux/chroot/container"
echo

build_amd64=false
build_i386=false

if ask_yes_no "Build x86_64 / amd64?" y; then build_amd64=true; fi
if ask_yes_no "Build i386 / 32-bit? Only works inside a 32-bit Linux environment." n; then build_i386=true; fi

if [[ "$build_amd64" == false && "$build_i386" == false ]]; then
    echo "Nothing selected. Exiting."
    exit 0
fi

echo
echo "Artifacts:"
make_portable=false
make_deb=false
make_rpm=false

if ask_yes_no "Create portable tar.gz?" y; then make_portable=true; fi
if ask_yes_no "Create DEB package?" y; then make_deb=true; fi
if ask_yes_no "Create RPM package?" n; then make_rpm=true; fi

if [[ "$make_portable" == false && "$make_deb" == false && "$make_rpm" == false ]]; then
    echo "No artifact type selected. Exiting."
    exit 0
fi

echo
echo "Summary:"
[[ "$build_amd64" == true ]] && echo "  amd64/x86_64: yes"
[[ "$build_i386" == true ]] && echo "  i386/32-bit: yes"
[[ "$make_portable" == true ]] && echo "  portable tar.gz: yes"
[[ "$make_deb" == true ]] && echo "  DEB: yes"
[[ "$make_rpm" == true ]] && echo "  RPM: yes"

if ! ask_yes_no "Continue?" y; then
    echo "Cancelled."
    exit 0
fi

mkdir -p dist
check_tools

build_target() {
    local arch="$1"
    local build_dir="$2"
    local package_arch="$3"
    local version
    version="$(get_project_version)"

    section "Building Linux $arch"

    if [[ "$arch" == "i386" ]]; then
        local machine
        machine="$(uname -m)"
        if [[ "$machine" != "i386" && "$machine" != "i686" ]]; then
            echo "i386 selected, but current machine is: $machine"
            echo "Please run this inside a 32-bit Linux chroot/container/VM."
            echo "This avoids unreliable cross-Qt multiarch builds."
            return 0
        fi
    fi

    rm -rf "$build_dir"
    cmake -S . -B "$build_dir" -G Ninja \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCPACK_PACKAGE_FILE_NAME="DostySpeak-$version-$package_arch"

    cmake --build "$build_dir" -j"$(nproc)"

    if [[ "$make_portable" == true ]]; then
        section "Creating portable tar.gz for $arch"
        local portable_dir="dist/DostySpeak-Linux-$package_arch"
        rm -rf "$portable_dir"
        mkdir -p "$portable_dir"
        cp "$build_dir/dosty-speak" "$portable_dir/"
        cp -r resources "$portable_dir/"
        cat > "$portable_dir/run-dosty-speak.sh" <<'RUN'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
./dosty-speak
RUN
        chmod +x "$portable_dir/run-dosty-speak.sh"
        tar -C dist -czf "dist/DostySpeak-Linux-$package_arch.tar.gz" "DostySpeak-Linux-$package_arch"
        echo "Created: dist/DostySpeak-Linux-$package_arch.tar.gz"
    fi

    if [[ "$make_deb" == true ]]; then
        section "Creating DEB for $arch"
        (cd "$build_dir" && cpack -G DEB)
        find "$build_dir" -maxdepth 1 -name "*.deb" -exec cp {} dist/ \;
    fi

    if [[ "$make_rpm" == true ]]; then
        section "Creating RPM for $arch"
        (cd "$build_dir" && cpack -G RPM)
        find "$build_dir" -maxdepth 1 -name "*.rpm" -exec cp {} dist/ \;
    fi
}

if [[ "$build_amd64" == true ]]; then
    build_target "x86_64" "build-linux-x86_64" "x86_64"
fi

if [[ "$build_i386" == true ]]; then
    build_target "i386" "build-linux-i386" "i386"
fi

section "Done"
echo "Outputs are in:"
echo "  $PROJECT_DIR/dist"
echo
find dist -maxdepth 1 -type f | sort
