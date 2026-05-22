#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")/.."

if [[ -f scripts/version.sh ]]; then
  # shellcheck source=/dev/null
  source scripts/version.sh
else
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

LOG_DIR="logs"
mkdir -p "$LOG_DIR"
BUILD_ID="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/dosty-speak-$DOSTY_SPEAK_VERSION-linux-build-$BUILD_ID.log"
LATEST_LOG="$LOG_DIR/latest-linux-build.log"
SELECTION_FILE="$(mktemp -t dosty-linux-build-selection.XXXXXX.json)"

: > "$LOG_FILE"
ln -sf "$(basename "$LOG_FILE")" "$LATEST_LOG" 2>/dev/null || cp "$LOG_FILE" "$LATEST_LOG"

selected_keys() {
  grep -o '"[^"]*"' "$SELECTION_FILE" | sed 's/"//g' | grep -v '^selected$' || true
}

shell_quote_for_log() {
  local out="" arg
  for arg in "$@"; do
    arg="${arg//\'/\'\\\\\'\'}"
    out="${out} '${arg}'"
  done
  printf "%s" "${out# }"
}

run_menu_ui() {
  if command -v python3 >/dev/null 2>&1; then
    python3 scripts/build_terminal_linux_ui.py "$SELECTION_FILE" "$DOSTY_SPEAK_VERSION" "$LOG_FILE"
  else
    clear
    echo "Python 3 is required for the graphical terminal builder."
    echo "Install it using your package manager, for example:"
    echo "  sudo apt install python3"
    echo
    echo '{"selected":["deps","linux_desktop","both_packages"]}' > "$SELECTION_FILE"
    read -r -p "Press Enter to continue with default Linux package build, or Ctrl+C to stop."
  fi
}

run_logged_interactive() {
  local title="$1"
  local step_index="$2"
  local total_steps="$3"
  shift 3

  {
    echo
    echo "============================================================"
    echo "$title"
    echo "Started: $(date)"
    echo "Command: $(shell_quote_for_log "$@")"
    echo "============================================================"
  } >> "$LOG_FILE"

  clear
  echo "Dosty Speak — interactive step"
  echo "=============================="
  echo
  echo "Version: $DOSTY_SPEAK_VERSION"
  echo "Step $((step_index + 1))/$total_steps: $title"
  echo
  echo "This step may ask for password or confirmations."
  echo "Type directly in this terminal."
  echo
  echo "Output is being written to:"
  echo "  $LOG_FILE"
  echo

  "$@" 2>&1 | tee -a "$LOG_FILE"
  local code=${PIPESTATUS[0]}

  {
    echo
    echo "Finished: $(date)"
    echo "Exit code: $code"
  } >> "$LOG_FILE"

  if [[ "$code" -ne 0 ]]; then
    echo
    echo "Step failed or paused for manual action."
    echo
    echo "Last 80 log lines:"
    echo "------------------------------------------------------------"
    tail -n 80 "$LOG_FILE" 2>/dev/null || true
    echo "------------------------------------------------------------"
    echo
    echo "Log saved to:"
    echo "  $LOG_FILE"
    echo
    read -r -p "Press Enter to continue, r to retry, or q to stop: " answer
    case "$answer" in
      r|R) run_logged_interactive "$title" "$step_index" "$total_steps" "$@" ;;
      q|Q) exit "$code" ;;
      *) return "$code" ;;
    esac
  fi
  return 0
}

run_logged_viewer() {
  local title="$1"
  local step_index="$2"
  local total_steps="$3"
  shift 3

  local done_file status_file
  done_file="$(mktemp -t dosty-linux-build-step-done.XXXXXX)"
  status_file="$(mktemp -t dosty-linux-build-step-status.XXXXXX)"
  rm -f "$done_file"
  echo "running" > "$status_file"

  {
    echo
    echo "============================================================"
    echo "$title"
    echo "Started: $(date)"
    echo "Command: $(shell_quote_for_log "$@")"
    echo "============================================================"
  } >> "$LOG_FILE"

  ("$@" >> "$LOG_FILE" 2>&1) &
  local pid=$!

  if command -v python3 >/dev/null 2>&1 && [[ -f scripts/build_log_viewer.py ]]; then
    python3 scripts/build_log_viewer.py "$LOG_FILE" "$DOSTY_SPEAK_VERSION" "$title" "$step_index" "$total_steps" "$pid" "$done_file" "$status_file" &
    local viewer_pid=$!
  else
    local viewer_pid=""
    echo "Building $title..."
  fi

  wait "$pid"
  local code=$?

  if [[ "$code" -eq 0 ]]; then
    echo "finished" > "$status_file"
  else
    echo "failed" > "$status_file"
  fi

  {
    echo
    echo "Finished: $(date)"
    echo "Exit code: $code"
  } >> "$LOG_FILE"

  touch "$done_file"

  if [[ -n "$viewer_pid" ]]; then
    wait "$viewer_pid" 2>/dev/null || true
  fi

  if [[ "$code" -ne 0 ]]; then
    clear
    echo "Step failed."
    echo
    echo "Last 80 log lines:"
    echo "------------------------------------------------------------"
    tail -n 80 "$LOG_FILE" 2>/dev/null || true
    echo "------------------------------------------------------------"
    echo
    echo "Log saved to:"
    echo "  $LOG_FILE"
    echo
    read -r -p "Press Enter to continue, r to retry, or q to stop: " answer
    case "$answer" in
      r|R) run_logged_viewer "$title" "$step_index" "$total_steps" "$@" ;;
      q|Q) exit "$code" ;;
      *) return "$code" ;;
    esac
  fi
  return 0
}

run_menu_ui

if [[ ! -s "$SELECTION_FILE" ]] || ! grep -q '"selected"' "$SELECTION_FILE"; then
  clear
  echo "No build selected."
  exit 0
fi

SELECTED=()
FAILED_KEYS=()
while IFS= read -r line; do
  SELECTED+=("$line")
done < <(selected_keys)

TOTAL_STEPS="${#SELECTED[@]}"
if [[ "$TOTAL_STEPS" -eq 0 ]]; then
  clear
  echo "No build selected."
  exit 0
fi

clear
echo "Build summary"
echo "============="
echo
echo "Linux TUI uses the same log viewer style as the macOS builder."
echo "DEB/RPM packaging is available from this menu."
echo
echo "Version: $DOSTY_SPEAK_VERSION"
echo "Log:     $LOG_FILE"
echo
echo "Selected:"
for key in "${SELECTED[@]}"; do
  echo "  - $key"
done
echo
read -r -p "Start build? [y/N]: " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

step_index=0
for key in "${SELECTED[@]}"; do
  case "$key" in
    deps)
      run_logged_interactive "Install/check Linux dependencies" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/install-linux-build-deps.sh && ./scripts/install-linux-build-deps.sh'
      ;;
    linux_desktop)
      if ! run_logged_viewer "Build Linux desktop app" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/build-linux-packages.sh && ./scripts/build-linux-packages.sh app'; then
        FAILED_KEYS+=("linux_desktop")
      fi
      ;;
    linux_install)
      if ! run_logged_interactive "Install Linux desktop app to this user" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/install-linux.sh && ./scripts/install-linux.sh'; then
        FAILED_KEYS+=("linux_install")
      fi
      ;;
    deb)
      if ! run_logged_viewer "Create DEB package" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/build-linux-packages.sh && ./scripts/build-linux-packages.sh deb'; then
        FAILED_KEYS+=("deb")
      fi
      ;;
    rpm)
      if ! run_logged_viewer "Create RPM package" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/build-linux-packages.sh && ./scripts/build-linux-packages.sh rpm'; then
        FAILED_KEYS+=("rpm")
      fi
      ;;
    both_packages)
      if ! run_logged_viewer "Create both DEB and RPM packages" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/build-linux-packages.sh && ./scripts/build-linux-packages.sh both'; then
        FAILED_KEYS+=("both_packages")
      fi
      ;;
    mobile_preview)
      if [[ -x scripts/build-mobile-preview-linux.sh ]]; then
        run_logged_viewer "Build Linux mobile preview" "$step_index" "$TOTAL_STEPS" bash -lc './scripts/build-mobile-preview-linux.sh' || true
      else
        run_logged_interactive "Build Linux mobile preview" "$step_index" "$TOTAL_STEPS" bash -lc 'echo "Linux mobile preview script is not present in this repository yet."; echo "Desktop and DEB/RPM packaging can still be built."; exit 0'
      fi
      ;;
    clean)
      run_logged_interactive "Clean Linux build/dist" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/build-linux-packages.sh && ./scripts/build-linux-packages.sh clean'
      ;;
  esac
  step_index=$((step_index + 1))
done

clear
echo "Done."
echo
echo "Version:"
echo "  $DOSTY_SPEAK_VERSION"
echo
echo "Full log:"
echo "  $LOG_FILE"
echo
echo "Latest log shortcut:"
echo "  $LATEST_LOG"
echo
echo "Artifacts:"
echo "  dist/linux/"
echo
echo "Commit check:"
echo "  git status"
echo "  git diff --stat"
echo
