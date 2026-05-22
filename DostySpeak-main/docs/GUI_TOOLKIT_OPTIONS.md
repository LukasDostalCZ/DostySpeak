# GUI toolkit options for Dosty Speak

## Current direction

The main modern app uses Qt and targets 64-bit systems.

For Windows x86, the project now uses a pure Win32 legacy frontend. This avoids the problem of missing 32-bit Qt/FLTK packages in current MSYS2 repositories.

## Long-term options

### Keep pure Win32 for x86

Best for old Windows compatibility and minimal dependencies.

Pros:
- no GUI toolkit dependency,
- builds with `mingw-w64-i686-gcc`,
- small executable,
- works well for basic phrase playback.

Cons:
- separate UI code,
- fewer modern widgets/features.

### wxWidgets branch later

A future wxWidgets branch could provide a nicer cross-platform old-hardware frontend.

Pros:
- C++,
- Windows/Linux/macOS,
- better native old-system story than Qt.

Cons:
- requires a larger port than pure Win32.

## Suggested direction

- Qt: modern 64-bit Windows/Linux/macOS.
- Pure Win32: old 32-bit Windows.
- Later: consider wxWidgets for a nicer cross-platform legacy frontend.
