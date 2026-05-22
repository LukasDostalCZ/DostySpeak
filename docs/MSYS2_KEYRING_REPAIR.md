# MSYS2 keyring repair

On some older Windows installations, especially Windows 10 LTSC with an older MSYS2 install, pacman can fail with errors like:

```text
signature ... is unknown trust
invalid or corrupted database (PGP signature)
database is not valid
```

Fix it from normal Windows PowerShell in the project folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\repair-msys2-keyring.ps1
```

Then run the release builder again:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release-terminal.ps1
```

If the repair cannot download package databases, check network/proxy/firewall and try again later.
