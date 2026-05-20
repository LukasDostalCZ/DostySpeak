# Windows packaging notes

Build in MSYS2 UCRT64 or Qt Creator.

After building, deploy Qt dependencies:

```powershell
windeployqt build\dosty-speak.exe
```

Then zip the deployed folder and upload it to GitHub Releases:

```powershell
Compress-Archive -Path build\* -DestinationPath DostySpeak-Windows.zip
```

For a nicer installer later, use NSIS or Inno Setup.
