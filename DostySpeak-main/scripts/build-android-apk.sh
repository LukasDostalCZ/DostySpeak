#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f scripts/version.sh ]]; then
  source scripts/version.sh
else
  DOSTY_SPEAK_VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
fi

echo "Dosty Speak — Android APK builder"
echo "================================="

find_android_sdk() {
  if [[ -n "${ANDROID_SDK_ROOT:-}" && -d "$ANDROID_SDK_ROOT" ]]; then echo "$ANDROID_SDK_ROOT"; return 0; fi
  if [[ -d "$HOME/Library/Android/sdk" ]]; then echo "$HOME/Library/Android/sdk"; return 0; fi
  if [[ -d "/opt/homebrew/share/android-commandlinetools" ]]; then echo "$HOME/Library/Android/sdk"; return 0; fi
  return 1
}

find_android_ndk() {
  local sdk="$1"
  if [[ -n "${ANDROID_NDK_ROOT:-}" && -d "$ANDROID_NDK_ROOT" ]]; then echo "$ANDROID_NDK_ROOT"; return 0; fi
  if [[ -n "$sdk" && -d "$sdk/ndk" ]]; then
    local preferred
    for version in 27.2.12479018 26.3.11579264 26.1.10909125; do
      if [[ -d "$sdk/ndk/$version" ]]; then
        echo "$sdk/ndk/$version"
        return 0
      fi
    done

    local ndk
    ndk="$(find "$sdk/ndk" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -n1 || true)"
    if [[ -n "$ndk" ]]; then echo "$ndk"; return 0; fi
  fi
  return 1
}

valid_qt_android_prefix() {
  local path="$1"
  [[ -n "$path" ]] || return 1
  [[ -f "$path/lib/cmake/Qt6/Qt6Config.cmake" ]] || return 1
  [[ -f "$path/lib/cmake/Qt6/qt.toolchain.cmake" ]] || return 1
  [[ "$path" == *android* ]] || return 1
  return 0
}

valid_qt_host_path() {
  local path="$1"
  [[ -n "$path" ]] || return 1
  [[ -f "$path/lib/cmake/Qt6/Qt6Config.cmake" ]] || return 1
  return 0
}

find_qt_android() {
  if [[ -n "${QT_ANDROID_PREFIX:-}" ]] && valid_qt_android_prefix "$QT_ANDROID_PREFIX"; then
    echo "$QT_ANDROID_PREFIX"
    return 0
  fi

  find "$HOME/Qt" -maxdepth 4 -type d -name "android_arm64_v8a" 2>/dev/null | while read -r candidate; do
    if valid_qt_android_prefix "$candidate"; then
      echo "$candidate"
      break
    fi
  done
}

find_qt_host_for_android() {
  local android_qt="$1"

  if [[ -n "${QT_HOST_PATH:-}" ]] && valid_qt_host_path "$QT_HOST_PATH"; then
    echo "$QT_HOST_PATH"
    return 0
  fi

  # Official Qt installer layout:
  # ~/Qt/6.11.1/android_arm64_v8a -> ~/Qt/6.11.1/macos
  local sibling
  sibling="$(cd "$android_qt/.." 2>/dev/null && pwd)/macos"
  if valid_qt_host_path "$sibling"; then
    echo "$sibling"
    return 0
  fi

  # Fallback for Homebrew Qt, useful for tools, but official Qt host is preferred.
  if command -v brew >/dev/null 2>&1; then
    local brew_qt
    brew_qt="$(brew --prefix qt 2>/dev/null || true)"
    if valid_qt_host_path "$brew_qt"; then
      echo "$brew_qt"
      return 0
    fi
  fi

  return 1
}


find_android_build_tools_bin() {
  local sdk="$1"
  if [[ -d "$sdk/build-tools" ]]; then
    find "$sdk/build-tools" -maxdepth 2 -type f -name apksigner 2>/dev/null | sort -V | tail -n1 | xargs dirname 2>/dev/null || true
  fi
}

sign_android_apk_if_needed() {
  local unsigned_apk="$1"
  local sdk="$2"
  local out_apk="$3"

  local tools
  tools="$(find_android_build_tools_bin "$sdk")"

  if [[ -z "$tools" || ! -x "$tools/apksigner" ]]; then
    echo "apksigner not found. Leaving unsigned APK:"
    echo "  $unsigned_apk"
    return 0
  fi

  local keystore="$HOME/.android/debug.keystore"
  mkdir -p "$HOME/.android"

  if [[ ! -f "$keystore" ]]; then
    echo "Creating debug keystore..."
    keytool -genkeypair \
      -v \
      -keystore "$keystore" \
      -storepass android \
      -alias androiddebugkey \
      -keypass android \
      -keyalg RSA \
      -keysize 2048 \
      -validity 10000 \
      -dname "CN=Android Debug,O=Android,C=US" >/dev/null
  fi

  local aligned="${out_apk%.apk}-aligned.apk"
  if [[ -x "$tools/zipalign" ]]; then
    "$tools/zipalign" -f 4 "$unsigned_apk" "$aligned"
  else
    cp "$unsigned_apk" "$aligned"
  fi

  "$tools/apksigner" sign \
    --ks "$keystore" \
    --ks-pass pass:android \
    --key-pass pass:android \
    --out "$out_apk" \
    "$aligned"

  "$tools/apksigner" verify "$out_apk"

  echo
  echo "Signed installable APK to install on Android:"
  echo "  $out_apk"
}

manual_android_help() {
  echo
  echo "Android build environment is incomplete."
  echo
  echo "The script can install Android command-line tools and SDK/NDK, but it cannot silently install Qt Android kit because Qt requires the official online installer/account flow."
  echo
  echo "Required:"
  echo "  Android SDK"
  echo "  Android NDK"
  echo "  Qt Android kit with lib/cmake/Qt6/qt.toolchain.cmake"
  echo "  Qt host kit, ideally sibling macos kit from the same Qt version"
  echo
  echo "Do this once:"
  echo "1) Open Qt Online Installer:"
  echo "   https://www.qt.io/download-qt-installer-oss"
  echo "2) Choose Custom Installation."
  echo "3) Select the same Qt version for:"
  echo "   macOS"
  echo "   Android arm64-v8a"
  echo "4) Expected paths:"
  echo "   $HOME/Qt/6.x.x/macos"
  echo "   $HOME/Qt/6.x.x/android_arm64_v8a"
  echo
  echo "Then run this script again."
}

# Bootstrap SDK/NDK if possible.
if command -v sdkmanager >/dev/null 2>&1; then
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
  export ANDROID_HOME="$ANDROID_SDK_ROOT"
  mkdir -p "$ANDROID_SDK_ROOT"
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "platforms;android-35" "build-tools;35.0.0" "ndk;27.2.12479018" >/dev/null || true
fi

ANDROID_SDK_ROOT="$(find_android_sdk || true)"
ANDROID_NDK_ROOT="$(find_android_ndk "$ANDROID_SDK_ROOT" || true)"
QT_ANDROID_PREFIX="$(find_qt_android || true)"

if [[ -z "$ANDROID_SDK_ROOT" || ! -d "$ANDROID_SDK_ROOT" ]]; then
  echo "Missing Android SDK."
  manual_android_help
  exit 1
fi

if [[ -z "$ANDROID_NDK_ROOT" || ! -d "$ANDROID_NDK_ROOT" ]]; then
  echo "Missing Android NDK."
  manual_android_help
  exit 1
fi

if [[ -z "$QT_ANDROID_PREFIX" ]] || ! valid_qt_android_prefix "$QT_ANDROID_PREFIX"; then
  echo "Missing or invalid Qt Android kit."
  if [[ -n "${QT_ANDROID_PREFIX:-}" ]]; then
    echo "Current QT_ANDROID_PREFIX:"
    echo "  $QT_ANDROID_PREFIX"
  fi
  manual_android_help
  exit 1
fi

QT_HOST_PATH="$(find_qt_host_for_android "$QT_ANDROID_PREFIX" || true)"
if [[ -z "$QT_HOST_PATH" ]] || ! valid_qt_host_path "$QT_HOST_PATH"; then
  echo "Missing Qt host kit."
  manual_android_help
  exit 1
fi

export ANDROID_SDK_ROOT
export ANDROID_NDK_ROOT
export QT_ANDROID_PREFIX
export QT_HOST_PATH

ABI="${ANDROID_ABI:-arm64-v8a}"
BUILD_DIR="build-android-${ABI}"

echo
echo "Using:"
echo "  Android SDK: $ANDROID_SDK_ROOT"
echo "  Android NDK: $ANDROID_NDK_ROOT"
echo "  Qt Android:  $QT_ANDROID_PREFIX"
echo "  Qt Host:     $QT_HOST_PATH"
echo "  ABI:         $ABI"
echo

rm -rf "$BUILD_DIR"

cmake -S mobile -B "$BUILD_DIR" \
  -G Ninja \
  -DCMAKE_PREFIX_PATH="$QT_ANDROID_PREFIX" \
  -DQt6_DIR="$QT_ANDROID_PREFIX/lib/cmake/Qt6" \
  -DQT_HOST_PATH="$QT_HOST_PATH" \
  -DANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
  -DANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" \
  -DANDROID_ABI="$ABI" \
  -DANDROID_PLATFORM="${ANDROID_PLATFORM:-android-23}" \
  -DQT_ANDROID_COMPILE_SDK_VERSION="${QT_ANDROID_COMPILE_SDK_VERSION:-36}" \
  -DCMAKE_TOOLCHAIN_FILE="$QT_ANDROID_PREFIX/lib/cmake/Qt6/qt.toolchain.cmake" \
  -DCMAKE_BUILD_TYPE=Release

if ! cmake --build "$BUILD_DIR" --parallel; then
  echo
  echo "Android build failed."
  echo "Useful debug files:"
  find "$BUILD_DIR/android-build" -maxdepth 2 -type f \( -name "build.gradle" -o -name "settings.gradle" -o -name "gradle.properties" \) -print 2>/dev/null || true
  echo
  echo "If Gradle says assembleRelease is missing, the Android package source directory likely contained a custom build.gradle."
  echo "This version removes that custom build.gradle so Qt can generate the correct Gradle project."
  exit 1
fi

echo
echo "Build finished."

UNSIGNED_APK="$(find "$BUILD_DIR/android-build/build/outputs/apk" "$BUILD_DIR/android-build" -type f -name "*unsigned*.apk" 2>/dev/null | head -n1 || true)"
if [[ -z "$UNSIGNED_APK" ]]; then
  UNSIGNED_APK="$(find "$BUILD_DIR" -type f -name "*.apk" 2>/dev/null | head -n1 || true)"
fi

mkdir -p dist/android

if [[ -n "$UNSIGNED_APK" ]]; then
  SIGNED_APK="dist/android/DostySpeak-Mobile-${DOSTY_SPEAK_VERSION}-${ABI}-debug-signed.apk"
  sign_android_apk_if_needed "$UNSIGNED_APK" "$ANDROID_SDK_ROOT" "$SIGNED_APK"
else
  echo "No APK found."
fi

echo
echo "APK output:"
find "$BUILD_DIR" dist/android -type f -name "*.apk" -print 2>/dev/null || true
