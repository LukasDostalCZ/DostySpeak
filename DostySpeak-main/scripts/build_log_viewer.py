#!/usr/bin/env python3
import curses
import os
import sys
import time
import re

LOG_FILE = sys.argv[1]
VERSION = sys.argv[2]
TITLE = sys.argv[3]
STEP_INDEX = int(sys.argv[4])
TOTAL_STEPS = int(sys.argv[5])
PID = sys.argv[6]
DONE_FILE = sys.argv[7]
STATUS_FILE = sys.argv[8]

PHASE_RULES = {
    "dependencies": [
        ("Installing desktop/mobile preview tools", 25),
        ("Installing Android helper tools", 45),
        ("Checking Android SDK", 65),
        ("Checking Qt Android/iOS kits", 80),
        ("Done.", 100),
    ],
    "macOS desktop": [
        ("macOS installer", 8),
        ("Source version:", 12),
        ("Configuring done", 25),
        ("Generating done", 35),
        ("Built target dosty-speak", 65),
        ("Running macdeployqt", 78),
        ("Ad-hoc signing app bundle", 90),
        ("Installed app version", 100),
    ],
    "mobile preview": [
        ("build mobile preview", 10),
        ("Configuring done", 30),
        ("Generating done", 40),
        ("Linking CXX executable", 70),
        ("copy_mobile_qml_for_preview", 86),
        ("Built:", 100),
    ],
    "Android": [
        ("Using:", 8),
        ("Configuring done", 20),
        ("Generating done", 30),
        ("Creating APK", 42),
        ("assembleRelease", 70),
        ("BUILD SUCCESSFUL", 86),
        ("Signed installable APK", 100),
    ],
    "iOS": [
        ("Using:", 12),
        ("Configuring done", 28),
        ("Generating done", 38),
        ("Generated Xcode project", 75),
        ("iOS build finished", 100),
        ("Skipping xcodebuild compile", 100),
    ],
    "ZIP": [
        ("Creating mobile preview ZIP", 30),
        ("Created:", 100),
    ],
}

def read_status():
    try:
        with open(STATUS_FILE, "r", encoding="utf-8", errors="replace") as f:
            return f.read().strip() or "running"
    except Exception:
        return "running"

def read_log_tail(max_lines):
    try:
        with open(LOG_FILE, "r", encoding="utf-8", errors="replace") as f:
            data = f.read()
    except Exception:
        return [], ""

    lines = data.splitlines()
    return lines[-max_lines:], data

def estimate_step_percent(log_text):
    percent = 3
    for key, rules in PHASE_RULES.items():
        if key in TITLE:
            for needle, value in rules:
                if needle in log_text:
                    percent = value
            break

    # CMake build percentage like [ 84%]
    matches = re.findall(r"\[\s*(\d{1,3})%\]", log_text)
    if matches:
        cmake_percent = max(int(x) for x in matches)
        # Use CMake percent as a middle section, not whole step.
        percent = max(percent, min(92, 35 + int(cmake_percent * 0.55)))

    if read_status() == "finished":
        percent = 100
    return max(0, min(100, percent))

def overall_percent(step_percent):
    if TOTAL_STEPS <= 0:
        return 0
    return int((STEP_INDEX * 100 + step_percent) / TOTAL_STEPS)

def fit(text, width):
    text = str(text)
    if width <= 0:
        return ""
    if len(text) <= width:
        return text
    return text[:max(0, width - 1)] + "…"

def add(stdscr, y, x, text, attr=0):
    h, w = stdscr.getmaxyx()
    if y < 0 or y >= h or x >= w:
        return
    if x < 0:
        text = text[-x:]
        x = 0
    try:
        stdscr.addstr(y, x, fit(text, w - x - 1), attr)
    except curses.error:
        pass

def bar(percent, width):
    width = max(10, width)
    filled = int(width * percent / 100)
    return "█" * filled + "░" * (width - filled)

def draw(stdscr):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.start_color()
    curses.init_pair(1, curses.COLOR_CYAN, -1)
    curses.init_pair(2, curses.COLOR_GREEN, -1)
    curses.init_pair(3, curses.COLOR_YELLOW, -1)
    curses.init_pair(4, curses.COLOR_RED, -1)
    curses.init_pair(5, curses.COLOR_BLUE, -1)
    curses.halfdelay(1)  # 0.1 s getch timeout, but we redraw less often below.

    last_draw = 0.0
    scroll = 0
    autoscroll = True

    while True:
        now = time.time()
        # Draw at about 4 fps, enough to feel live, not enough to flicker.
        if now - last_draw >= 0.25:
            h, w = stdscr.getmaxyx()
            tail_height = max(5, h - 12)
            lines, log_text = read_log_tail(tail_height + max(0, scroll))
            if scroll > 0:
                # Show older lines when user scrolls up.
                try:
                    with open(LOG_FILE, "r", encoding="utf-8", errors="replace") as f:
                        all_lines = f.read().splitlines()
                    start = max(0, len(all_lines) - tail_height - scroll)
                    lines = all_lines[start:start + tail_height]
                except Exception:
                    pass

            step_percent = estimate_step_percent(log_text)
            overall = overall_percent(step_percent)
            status = read_status()

            stdscr.erase()

            header_attr = curses.color_pair(1) | curses.A_BOLD
            status_attr = curses.color_pair(2) if status == "finished" else curses.color_pair(3)
            if status == "failed":
                status_attr = curses.color_pair(4) | curses.A_BOLD

            add(stdscr, 0, 0, "Dosty Speak build", header_attr)
            add(stdscr, 0, 22, f"version {VERSION}", curses.A_BOLD)
            add(stdscr, 0, 42, status, status_attr)
            add(stdscr, 1, 0, "─" * (w - 1), curses.color_pair(5))

            add(stdscr, 2, 0, f"Step {STEP_INDEX + 1}/{TOTAL_STEPS}: {TITLE}", curses.A_BOLD)
            add(stdscr, 3, 0, f"Log: {LOG_FILE}")
            add(stdscr, 4, 0, f"PID: {PID}")
            add(stdscr, 5, 0, "Controls: q stop viewing after step ends, ↑/↓ scroll log, End autoscroll")

            bar_width = max(20, min(70, w - 18))
            add(stdscr, 7, 0, f"Overall [{bar(overall, bar_width)}] {overall:3d}%")
            add(stdscr, 8, 0, f"Step    [{bar(step_percent, bar_width)}] {step_percent:3d}%")

            add(stdscr, 10, 0, "Live console" + ("  (scrolled)" if scroll > 0 else ""), curses.A_BOLD)
            add(stdscr, 11, 0, "─" * (w - 1), curses.color_pair(5))

            y = 12
            for line in lines[-tail_height:]:
                add(stdscr, y, 0, line)
                y += 1
                if y >= h - 1:
                    break

            stdscr.noutrefresh()
            curses.doupdate()
            last_draw = now

        key = stdscr.getch()
        if key == curses.KEY_UP:
            scroll += 1
        elif key == curses.KEY_DOWN:
            scroll = max(0, scroll - 1)
        elif key == curses.KEY_END:
            scroll = 0
        elif key in (ord("q"), ord("Q")) and os.path.exists(DONE_FILE):
            break

        if os.path.exists(DONE_FILE):
            # Keep final screen visible for a short moment then return to shell.
            time.sleep(0.45)
            break

def main():
    curses.wrapper(draw)

if __name__ == "__main__":
    main()
