#!/usr/bin/env bash
set -u

APP_NAME="Dosty Speak"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_VERSION="0.0.0"
[[ -f VERSION ]] && APP_VERSION="$(tr -d '[:space:]' < VERSION)"

LOG_DIR="$ROOT_DIR/logs"
DIST_DIR="$ROOT_DIR/dist/linux"
mkdir -p "$LOG_DIR" "$DIST_DIR"
LOG_FILE="$LOG_DIR/dosty-speak-${APP_VERSION}-linux-build-$(date +%Y%m%d-%H%M%S).log"
LATEST_LOG="$LOG_DIR/latest-linux-build.log"

if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  c_reset="$(tput sgr0 || true)"
  c_bold="$(tput bold || true)"
  c_dim="$(tput dim || true)"
  c_cyan="$(tput setaf 6 || true)"
  c_green="$(tput setaf 2 || true)"
  c_yellow="$(tput setaf 3 || true)"
  c_red="$(tput setaf 1 || true)"
else
  c_reset=""; c_bold=""; c_dim=""; c_cyan=""; c_green=""; c_yellow=""; c_red=""
fi

items=(
  "Install/check Linux dependencies"
  "Build Linux desktop app"
  "Create DEB package"
  "Create RPM package"
  "Create both DEB and RPM"
  "Build Linux mobile preview"
  "Clean Linux build/dist"
)
selected=(1 2 5)

contains() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
  return 1
}

toggle_item() {
  local n="$1" item found=0 out=()
  for item in "${selected[@]}"; do
    if [[ "$item" == "$n" ]]; then
      found=1
    else
      out+=("$item")
    fi
  done
  [[ "$found" == "0" ]] && out+=("$n")
  selected=("${out[@]}")
}

header() {
  clear 2>/dev/null || true
  printf '%b%s%b\n' "$c_cyan$c_bold" "$APP_NAME - Linux terminal builder" "$c_reset"
  printf '%b%s%b\n' "$c_dim" "================================================" "$c_reset"
  printf 'Version: %s\n' "$APP_VERSION"
  printf 'Log:     %s\n\n' "$LOG_FILE"
}

draw_menu() {
  header
  printf '%bControls:%b type numbers separated by spaces, Enter builds selected, a toggles all, q quits\n\n' "$c_dim" "$c_reset"
  local i n mark
  for i in "${!items[@]}"; do
    n=$((i + 1))
    mark=" "
    contains "$n" "${selected[@]}" && mark="x"
    printf '  %d) [%s] %s\n' "$n" "$mark" "${items[$i]}"
  done
  printf '\nRecommended full Linux build: 1 2 5\n'
}

read_menu_choice() {
  local line part
  printf '\nSelection: '
  IFS= read -r line || exit 0
  [[ -z "$line" ]] && return 0
  case "$line" in
    q|Q) exit 0 ;;
    a|A)
      if [[ ${#selected[@]} -eq ${#items[@]} ]]; then
        selected=()
      else
        selected=(1 2 3 4 5 6 7)
      fi
      return 1
      ;;
  esac
  for part in $line; do
    [[ "$part" =~ ^[1-7]$ ]] && toggle_item "$part"
  done
  return 1
}

confirm() {
  header
  printf 'Summary:\n'
  local i n mark
  for i in "${!items[@]}"; do
    n=$((i + 1))
    mark=" "
    contains "$n" "${selected[@]}" && mark="x"
    printf '  [%s] %s\n' "$mark" "${items[$i]}"
  done
  printf '\nContinue? [y/N]: '
  local ans
  IFS= read -r ans || exit 1
  [[ "$ans" =~ ^[Yy]$ ]]
}

run_step() {
  local title="$1"; shift
  local code started finished ans

  printf '\n%b============================================================%b\n' "$c_dim" "$c_reset" | tee -a "$LOG_FILE"
  printf '%s\n' "$title" | tee -a "$LOG_FILE"
  started="$(date)"
  printf 'Started: %s\n' "$started" | tee -a "$LOG_FILE"
  printf 'Command:' | tee -a "$LOG_FILE"
  printf ' %q' "$@" | tee -a "$LOG_FILE"
  printf '\n%b============================================================%b\n' "$c_dim" "$c_reset" | tee -a "$LOG_FILE"

  set +e
  "$@" 2>&1 | tee -a "$LOG_FILE"
  code=${PIPESTATUS[0]}
  set -u

  finished="$(date)"
  printf '\nFinished: %s\nExit code: %s\n' "$finished" "$code" | tee -a "$LOG_FILE"
  ln -sf "$(basename "$LOG_FILE")" "$LATEST_LOG" 2>/dev/null || cp "$LOG_FILE" "$LATEST_LOG" 2>/dev/null || true

  if [[ "$code" != "0" ]]; then
    printf '\n%bStep failed.%b\nLog saved here:\n  %s\n' "$c_red" "$c_reset" "$LOG_FILE"
    printf 'Press Enter to continue, r to retry, or q to stop: '
    IFS= read -r ans || true
    case "$ans" in
      q|Q) exit "$code" ;;
      r|R) run_step "$title" "$@" ;;
    esac
  fi
}

install_deps() {
  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y build-essential cmake ninja-build qt6-base-dev qt6-base-dev-tools qt6-declarative-dev espeak-ng alsa-utils rpm
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y gcc-c++ cmake ninja-build qt6-qtbase-devel qt6-qtdeclarative-devel espeak-ng alsa-utils rpm-build
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y gcc-c++ cmake ninja qt6-base-devel qt6-declarative-devel espeak-ng alsa-utils rpm-build
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed base-devel cmake ninja qt6-base qt6-declarative espeak-ng alsa-utils rpm-tools
  else
    printf 'Unsupported package manager. Install CMake, Qt, compiler and rpm tools manually.\n' >&2
    return 1
  fi
}

while true; do
  draw_menu
  read_menu_choice || continue
  break
done

confirm || exit 0
: > "$LOG_FILE"
chmod +x scripts/build-linux-packages.sh 2>/dev/null || true

for n in "${selected[@]}"; do
  case "$n" in
    1) run_step "Install/check Linux dependencies" bash -lc "$(declare -f install_deps); install_deps" ;;
    2) run_step "Build Linux desktop app" bash -lc './scripts/build-linux-packages.sh app' ;;
    3) run_step "Create DEB package" bash -lc './scripts/build-linux-packages.sh deb' ;;
    4) run_step "Create RPM package" bash -lc './scripts/build-linux-packages.sh rpm' ;;
    5) run_step "Create both DEB and RPM" bash -lc './scripts/build-linux-packages.sh both' ;;
    6) run_step "Build Linux mobile preview" bash -lc 'rm -rf build-mobile-preview-linux && cmake -S mobile -B build-mobile-preview-linux -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build build-mobile-preview-linux --parallel' ;;
    7) run_step "Clean Linux build/dist" bash -lc './scripts/build-linux-packages.sh clean' ;;
  esac
done

header
printf '%bDone.%b\n\n' "$c_green" "$c_reset"
printf 'Log saved here:\n  %s\n\n' "$LOG_FILE"
printf 'Linux artifacts:\n'
find "$DIST_DIR" -maxdepth 1 -type f 2>/dev/null | sort || true
