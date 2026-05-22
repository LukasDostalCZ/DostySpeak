# macOS build and packaging

These commands assume you are inside the project folder.

## Create app in Applications

```bash
chmod +x scripts/install-macos.sh
./scripts/install-macos.sh
open "$HOME/Applications/Dosty Speak.app"
```

This creates:

```text
~/Applications/Dosty Speak.app
```

The bundle includes:

```text
Contents/MacOS/dosty-speak
Contents/Resources/resources/
```

If `macdeployqt` is available, the script attempts to deploy Qt libraries into the bundle.

## Manual build only

```bash
brew install cmake qt

rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$(brew --prefix qt)"
cmake --build build -j"$(sysctl -n hw.ncpu)"

./build/dosty-speak
```

## Create DMG

After the `.app` exists:

```bash
macdeployqt "$HOME/Applications/Dosty Speak.app" -dmg
```
