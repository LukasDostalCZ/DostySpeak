#!/usr/bin/env bash
# Shared version helper. Source this file from shell scripts.
DOSTY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSTY_VERSION_FILE="$DOSTY_ROOT/VERSION"
if [[ -f "$DOSTY_VERSION_FILE" ]]; then
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < "$DOSTY_VERSION_FILE")"
else
  DOSTY_SPEAK_VERSION="0.0.0"
fi
export DOSTY_SPEAK_VERSION
