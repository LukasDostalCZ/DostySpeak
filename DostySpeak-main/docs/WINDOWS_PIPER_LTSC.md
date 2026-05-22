# Windows Piper on Windows 10 LTSC

Windows 10 2019 LTSC can miss the Microsoft Visual C++ Runtime required by the official standalone Piper executable.

Typical error messages:

```text
VCRUNTIME140.dll was not found
MSVCP140.dll was not found
```

## Automatic help inside Dosty Speak

In the main Windows 64-bit app, use:

```text
Voice -> Install Microsoft VC++ Runtime
```

The app downloads the official Microsoft Visual C++ Redistributable x64 installer:

```text
https://aka.ms/vs/17/release/vc_redist.x64.exe
```

and starts it with normal Windows administrator elevation.

## Manual fix

Download and install:

```text
https://aka.ms/vs/17/release/vc_redist.x64.exe
```

Then restart Dosty Speak and try Piper again.

## Note

This affects the 64-bit Windows build only. The 32-bit legacy build does not support Piper.
