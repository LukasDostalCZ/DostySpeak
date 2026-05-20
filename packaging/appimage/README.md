# AppImage notes

A simple approach using linuxdeployqt:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build -j"$(nproc)"
DESTDIR=AppDir cmake --install build

linuxdeployqt AppDir/usr/share/applications/dosty-speak.desktop -appimage
```
