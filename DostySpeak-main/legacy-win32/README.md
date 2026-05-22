# Dosty Speak Legacy Win32

Pure Win32 lightweight frontend for old Windows and 32-bit builds.

Why this exists:

- current MSYS2 on some machines has no i686 Qt and no i686 FLTK,
- pure Win32 API needs no GUI toolkit package,
- it can be built with the available `mingw-w64-i686-gcc`,
- it uses Windows SAPI directly through COM.

This is intentionally simpler than the Qt app, but it is the most realistic
fallback for 32-bit Windows on restricted toolchains.
