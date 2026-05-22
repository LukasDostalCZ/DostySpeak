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
LOG_FILE="$LOG_DIR/dosty-speak-$DOSTY_SPEAK_VERSION-macos-build-$BUILD_ID.log"
LATEST_LOG="$LOG_DIR/latest-macos-build.log"
SELECTION_FILE="$(mktemp -t dosty-build-selection.XXXXXX.json)"

: > "$LOG_FILE"
ln -sf "$(basename "$LOG_FILE")" "$LATEST_LOG" 2>/dev/null || cp "$LOG_FILE" "$LATEST_LOG"

has_selection() {
  local key="$1"
  grep -q "\"$key\"" "$SELECTION_FILE" 2>/dev/null
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
    python3 scripts/build_terminal_macos_ui.py "$SELECTION_FILE" "$DOSTY_SPEAK_VERSION" "$LOG_FILE"
  else
    clear
    echo "Python 3 is required for the graphical terminal builder."
    echo "Install it with:"
    echo "  brew install python"
    echo
    echo "{\"selected\":[\"deps\",\"mac_desktop\"]}" > "$SELECTION_FILE"
    read -r -p "Press Enter to continue with default desktop build, or Ctrl+C to stop."
  fi
}

selected_keys() {
  grep -o '"[^"]*"' "$SELECTION_FILE" | sed 's/"//g' | grep -v '^selected$' || true
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
    echo "Step failed or paused for manual action. Last 80 log lines:"
    echo "------------------------------------------------------------"
    tail -n 80 "$LOG_FILE" 2>/dev/null || true
    echo "------------------------------------------------------------"
    echo
    echo "Log:"
    echo "  $LOG_FILE"
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
  done_file="$(mktemp -t dosty-build-step-done.XXXXXX)"
  status_file="$(mktemp -t dosty-build-step-status.XXXXXX)"
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

  if command -v python3 >/dev/null 2>&1; then
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
    echo "Desktop CMake quick check:"
    echo "  ./scripts/diagnose-desktop-cmake.sh"
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
echo "Builder is the only supported entry point for normal compiling."
echo "Pick everything here; you do not need to run separate build scripts manually."
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
      run_logged_interactive "Install/check dependencies" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/install-mobile-build-deps-macos.sh && ./scripts/install-mobile-build-deps-macos.sh'
      ;;
    mac_desktop)
      if ! run_logged_viewer "Build and install macOS desktop app" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/install-macos.sh && ./scripts/install-macos.sh'; then
        FAILED_KEYS+=("mac_desktop")
      fi
      ;;
    mac_package)
      if printf '%s
' "${FAILED_KEYS[@]}" | grep -q '^mac_desktop$'; then
        echo "Skipping macOS desktop release package because desktop build failed."
      else
        run_logged_viewer "Create macOS desktop release package" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/package-macos-desktop.sh && ./scripts/package-macos-desktop.sh' || true
      fi
      ;;
    mobile_preview)
      if ! run_logged_viewer "Build mobile preview for this Mac" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/build-mobile-preview-macos.sh && ./scripts/build-mobile-preview-macos.sh'; then
        FAILED_KEYS+=("mobile_preview")
      fi
      ;;
    run_mobile_preview)
      if printf '%s
' "${FAILED_KEYS[@]}" | grep -q '^mobile_preview$'; then
        echo "Skipping Run mobile preview because Build mobile preview failed."
      else
        run_logged_viewer "Run mobile preview" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/run-mobile-preview-macos.sh && ./scripts/run-mobile-preview-macos.sh' || true
      fi
      ;;
    mobile_package)
      if printf '%s
' "${FAILED_KEYS[@]}" | grep -q '^mobile_preview$'; then
        echo "Skipping mobile preview ZIP because Build mobile preview failed."
      else
        run_logged_viewer "Create mobile preview ZIP" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/package-mobile-preview-macos.sh && ./scripts/package-mobile-preview-macos.sh' || true
      fi
      ;;
    android)
      if ! run_logged_viewer "Build Android APK" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/build-android-apk.sh && ./scripts/build-android-apk.sh'; then
        FAILED_KEYS+=("android")
      fi
      ;;
    android_install)
      run_logged_interactive "Install Android APK to connected phone" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/install-android-apk.sh && ./scripts/install-android-apk.sh' || true
      ;;
    android_log)
      run_logged_interactive "Capture Android crash log" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/capture-android-crash-log.sh && ./scripts/capture-android-crash-log.sh' || true
      ;;
    qt_ios)
      run_logged_interactive "Install/check Qt iOS kit" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/install-qt-ios-kit-macos.sh && ./scripts/install-qt-ios-kit-macos.sh' || true
      ;;
    ios_prepare)
      run_logged_interactive "Prepare iPhone install in Xcode" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/prepare-ios-iphone.sh && ./scripts/prepare-ios-iphone.sh' || true
      ;;
    ios)
      run_logged_interactive "Build iOS app / Xcode project" "$step_index" "$TOTAL_STEPS" bash -lc 'chmod +x scripts/build-ios.sh && ./scripts/build-ios.sh'
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
echo "Artifacts are usually in:"
echo "  dist/"
echo "  dist/android/"
echo "  build-mobile-preview-macos/"
echo "  build-android-arm64-v8a/"
echo

if command -v open >/dev/null 2>&1; then
  read -r -p "Open log folder? [y/N]: " open_answer
  [[ "$open_answer" =~ ^[Yy]$ ]] && open "$LOG_DIR" >/dev/null 2>&1 || true
fi
