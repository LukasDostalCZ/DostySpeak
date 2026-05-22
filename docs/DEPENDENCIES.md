# Optional dependency installation

Dosty Speak can help install optional speech dependencies.

## Edge TTS

Menu:

```text
Voice -> Install Edge TTS
```

Behavior:

- Windows: downloads official Python 3.11 installer into app data, installs it locally for the user, creates a private venv and installs `edge-tts`.
- macOS/Linux: creates a private venv in app data and installs `edge-tts` with pip.

If Linux misses venv support, install:

```bash
sudo apt install python3-venv
```

## eSpeak NG

Menu:

```text
Voice -> Install eSpeak NG
```

Behavior:

- Windows: tries winget package install if winget is available.
- macOS: runs `brew install espeak-ng`.
- Linux: tries apt/dnf/zypper/pacman.

If automatic install fails, install `espeak-ng` manually with your system package manager.
