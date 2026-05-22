# Sync this package into your git checkout

This package is a complete working-tree version of Dosty Speak. To let git show the real differences, use the sync script instead of copying files manually.

The sync script preserves the target `.git` directory, backs up the current working tree, then replaces all project files with this package.

## macOS / Linux

Unzip this package somewhere temporary, then run:

```bash
cd ~/Downloads/dosty-speak
chmod +x tools/sync-this-version-to-git.sh
./tools/sync-this-version-to-git.sh ~/Dev/dosty-speak
```

Then review and commit:

```bash
cd ~/Dev/dosty-speak
git status
git diff --stat
git diff
git add -A
git commit -m "Update Dosty Speak"
git push
```

## Windows PowerShell

Unzip this package somewhere temporary, then run:

```powershell
cd $env:USERPROFILE\Downloads\dosty-speak
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\sync-this-version-to-git.ps1 $env:USERPROFILE\Dev\dosty-speak
```

If your git checkout is on Desktop, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\sync-this-version-to-git.ps1 $env:USERPROFILE\Desktop\dosty-speak
```

Then review and commit:

```powershell
cd $env:USERPROFILE\Dev\dosty-speak
git status
git diff --stat
git diff
git add -A
git commit -m "Update Dosty Speak"
git push
```
