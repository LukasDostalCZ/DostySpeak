# Dosty Speak 0.3.59 commit-ready update

This full zip is based on the latest complete 0.3.57 project you sent and includes Linux DEB/RPM packaging.

Changed files prepared for commit:

- `VERSION`
- `CMakeLists.txt`
- `cmake/DostyPackaging.cmake`
- `scripts/build-terminal-linux.sh`
- `scripts/build-linux-packages.sh`
- `scripts/apply-linux-packaging-fix.sh`
- `docs/TUI-RUN-INSTRUCTIONS.md`
- `README-COMMIT.md`

Recommended apply flow:

```bash
cd ~/Dev
rm -rf dosty-speak
unzip ~/Downloads/dosty-speak-0.3.59-full-commit-ready.zip
cd dosty-speak
chmod +x scripts/*.sh
```

Commit and push:

```bash
git status
git diff
git add CMakeLists.txt VERSION cmake/DostyPackaging.cmake scripts/build-terminal-linux.sh scripts/build-linux-packages.sh scripts/apply-linux-packaging-fix.sh docs/TUI-RUN-INSTRUCTIONS.md README-COMMIT.md
git commit -m "Add Linux DEB and RPM packaging"
git push
```

Run the Linux builder:

```bash
./scripts/build-terminal-linux.sh
```

Build both Linux packages directly:

```bash
./scripts/build-linux-packages.sh both
```
