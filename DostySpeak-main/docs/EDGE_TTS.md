# Microsoft Edge online voice

Dosty Speak includes a Microsoft Edge online voice engine through the `edge-tts` command line tool.

## Requirements

Install `edge-tts`:

```bash
python -m pip install edge-tts
```

On Linux/macOS you can install it into your user Python environment or a venv.

On Windows, if Python is not available on a particular LTSC machine, keep using Piper, native voice, Google online voice, or install Python manually.

## Voices

The app currently exposes:

- Czech: `cs-CZ-AntoninNeural`
- English: `en-US-GuyNeural`
- Slovak: `sk-SK-LukasNeural`
- German: `de-DE-ConradNeural`
- Polish: `pl-PL-MarekNeural`
- French: `fr-FR-HenriNeural`

## Notes

This engine requires internet. It can sound better than the simple Google online voice, but depends on the external `edge-tts` tool.


## Automatic install

Use:

```text
Voice -> Install Edge TTS
```

Dosty Speak creates its own private environment for `edge-tts` where possible.
