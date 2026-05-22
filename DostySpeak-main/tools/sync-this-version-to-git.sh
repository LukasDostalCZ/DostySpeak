#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST_ROOT="${1:-}"

if [[ -z "$DEST_ROOT" ]]; then
  cat <<USAGE
Dosty Speak - sync this package into an existing git checkout

Usage:
  tools/sync-this-version-to-git.sh /path/to/existing/dosty-speak

Example:
  tools/sync-this-version-to-git.sh ~/Dev/dosty-speak

This preserves only the target .git directory and replaces the working tree
with this packaged version, so git can show all differences.
USAGE
  exit 2
fi

DEST_ROOT="$(cd "$DEST_ROOT" && pwd)"

if [[ "$SOURCE_ROOT" == "$DEST_ROOT" ]]; then
  echo "Refusing to sync onto the same directory."
  echo "Unzip this package into a temporary folder, then pass your real git checkout as the argument."
  exit 1
fi

if [[ ! -d "$DEST_ROOT/.git" ]]; then
  echo "Target does not contain .git: $DEST_ROOT"
  echo "Use your existing git checkout as the target."
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required. Install it and run again."
  exit 1
fi

VERSION="unknown"
if [[ -f "$SOURCE_ROOT/VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "$SOURCE_ROOT/VERSION")"
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$DEST_ROOT/../dosty-speak-backup-before-sync-$VERSION-$STAMP.tar.gz"

echo "Dosty Speak - sync package to git checkout"
echo "============================================"
echo "Source: $SOURCE_ROOT"
echo "Target: $DEST_ROOT"
echo "Version: $VERSION"
echo

echo "Creating safety backup without .git:"
echo "  $BACKUP"
tar --exclude='.git' -czf "$BACKUP" -C "$DEST_ROOT" .

echo
echo "Replacing working tree while preserving .git..."

# Remove everything except .git from target root, including hidden files.
find "$DEST_ROOT" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

# Copy package content into target. Exclude transient local build outputs just in case.
rsync -a \
  --exclude='.git/' \
  --exclude='build-*/' \
  --exclude='dist/' \
  --exclude='logs/' \
  --exclude='*.user' \
  "$SOURCE_ROOT/" "$DEST_ROOT/"

chmod +x "$DEST_ROOT"/scripts/*.sh 2>/dev/null || true
chmod +x "$DEST_ROOT"/tools/*.sh 2>/dev/null || true

echo
echo "Done. Git status in target:"
cd "$DEST_ROOT"
git status --short

echo
echo "Next recommended commands:"
echo "  git diff --stat"
echo "  git diff"
echo "  git add -A"
echo "  git commit -m \"Update Dosty Speak to $VERSION\""
echo "  git push"
