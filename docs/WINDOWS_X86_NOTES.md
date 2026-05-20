# Windows x86 notes

The Windows x86 release now uses a pure Win32 legacy frontend.

It does not use:

- Qt,
- FLTK,
- Piper,
- Python,
- any external GUI toolkit.

It only needs:

```text
mingw-w64-i686-gcc
```

The output is:

```text
dist\DostySpeak-Legacy-Win32-Portable-x86.zip
```

This legacy version is intentionally simpler than the main Qt app. It uses Windows SAPI directly, has basic phrase playback, speed and volume controls, and is meant for older 32-bit Windows hardware.
