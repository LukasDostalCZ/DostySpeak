#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Dosty Speak — mobile bridge diagnostics"
echo "======================================="
echo

echo "VERSION:"
cat VERSION
echo

echo "MobileBridge declarations in main_mobile.cpp:"
grep -n 'MobileBridge bridge' mobile/main_mobile.cpp || true
echo

echo "Context property lines:"
grep -n 'setContextProperty' mobile/main_mobile.cpp || true
echo

count="$(grep -c 'MobileBridge bridge' mobile/main_mobile.cpp || true)"
if [[ "$count" != "1" ]]; then
  echo "ERROR: expected exactly one MobileBridge bridge declaration, found $count"
  exit 1
fi

echo "OK: exactly one bridge declaration."
