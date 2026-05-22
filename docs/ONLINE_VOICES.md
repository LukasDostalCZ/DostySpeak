# Online voices

Dosty Speak includes an optional online voice engine:

```text
Online Google voice
```

It uses a public Google Translate TTS endpoint and downloads MP3 audio for the selected language.

## Important notes

- It requires internet.
- It uses an unofficial endpoint and may stop working if Google changes the endpoint.
- Long texts are shortened before sending because the endpoint is unreliable with long requests.
- Piper and native voices remain the recommended reliable engines.

## Playback

- Windows uses Windows Media Player COM to play MP3.
- macOS uses `afplay`.
- Linux needs `ffplay` from ffmpeg or `mpg123`.
