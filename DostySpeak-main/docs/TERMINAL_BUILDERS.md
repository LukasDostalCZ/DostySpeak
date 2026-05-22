# Terminal builders

Dosty Speak includes graphical terminal builders for macOS, Linux and Windows.

## macOS

```bash
./scripts/build-terminal-macos.sh
```

## Linux

```bash
./scripts/build-terminal-linux.sh
```

## Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-terminal-windows.ps1
```

## Controls

```text
Up/Down  move selection
Space    toggle selected item
Enter    start build
a        toggle all
q        quit
```

## Logs

Every build creates a timestamped log file:

```text
logs/macos-build-YYYYMMDD-HHMMSS.log
logs/linux-build-YYYYMMDD-HHMMSS.log
logs/windows-build-YYYYMMDD-HHMMSS.log
```

Latest shortcuts:

```text
logs/latest-macos-build.log
logs/latest-linux-build.log
logs/latest-windows-build.log
```

During non-interactive build steps, the builder shows a progress bar and a live tail of the log.


## macOS controls

```text
Up/Down  move selection
Space    toggle highlighted item
1-6      toggle item by number
Mouse    click item to select/toggle, where supported
Enter    start build
a        toggle all
l        open logs folder
q        quit
```

The macOS builder is compatible with the default Bash 3.2 and handles multiple terminal arrow-key escape formats.


## macOS navigation fallback

The macOS builder supports both arrow keys and `j/k` navigation:

```text
j  move down
k  move up
```

Mouse support is disabled by default. Press `m` to enable or disable mouse reporting.


## macOS builder implementation

The macOS builder uses Python/curses for the menu. This is more reliable than parsing raw ANSI escape sequences in shell.

If Python 3 is missing, install it:

```bash
brew install python
```
