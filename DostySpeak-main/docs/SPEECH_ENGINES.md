# Speech engines

Dosty Speak supports multiple speech engines.

## Native system voice

Uses the operating system voice:

- Windows: System.Speech / SAPI
- macOS: `say`
- Linux: `espeak-ng`

This is the most basic and usually most compatible option.

## Piper

Offline neural voice engine. Best quality when a good voice model is selected.

On Windows 64-bit Dosty Speak can download the standalone Piper runtime. On Linux/macOS it uses a Python virtual environment.

## Online Google voice

Online voice based on a public Google Translate TTS endpoint.

- requires internet,
- good for quick Czech/English online output,
- may be less reliable for long texts,
- does not replace Piper.

## eSpeak NG

Explicit eSpeak NG engine.

- offline,
- very fast,
- robotic voice,
- useful on slow hardware,
- requires `espeak-ng` to be installed or available in PATH.


## Microsoft Edge online voice

Online neural voice through the `edge-tts` command line tool.

- requires internet,
- requires `edge-tts`,
- often sounds more natural than basic online TTS,
- configured in Settings with the Edge TTS command path.
