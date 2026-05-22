#!/usr/bin/env python3
import curses
import json
import os
import sys
import textwrap

OUT_FILE = sys.argv[1]
VERSION = sys.argv[2]
LOG_FILE = sys.argv[3]

OPTIONS = [
    {"key": "deps", "group": "Setup", "label": "Install/check Linux dependencies", "desc": "Installs/checks compiler, CMake, Ninja, Qt, eSpeak/ALSA and packaging tools."},

    {"key": "linux_desktop", "group": "Linux desktop", "label": "Build Linux desktop app", "desc": "Builds the Linux desktop app in Release mode."},
    {"key": "linux_install", "group": "Linux desktop", "label": "Install Linux desktop app to this user", "desc": "Builds and installs Dosty Speak into ~/.local."},

    {"key": "deb", "group": "Linux packages", "label": "Create DEB package", "desc": "Creates a Debian/Ubuntu .deb package in dist/linux."},
    {"key": "rpm", "group": "Linux packages", "label": "Create RPM package", "desc": "Creates a Fedora/openSUSE .rpm package in dist/linux."},
    {"key": "both_packages", "group": "Linux packages", "label": "Create both DEB and RPM packages", "desc": "Creates both package formats in dist/linux."},

    {"key": "mobile_preview", "group": "Mobile preview", "label": "Build Linux mobile preview", "desc": "Builds the Qt Quick mobile preview for this Linux machine when mobile sources are available."},

    {"key": "clean", "group": "Maintenance", "label": "Clean Linux build/dist", "desc": "Removes Linux build directories and dist/linux outputs."},
]

DEFAULT_SELECTED = {
    "deps": True,
    "linux_desktop": True,
    "linux_install": False,
    "deb": False,
    "rpm": False,
    "both_packages": True,
    "mobile_preview": False,
    "clean": False,
}

PRESETS = {
    "1": ("Desktop build", ["deps", "linux_desktop"]),
    "2": ("Desktop install", ["deps", "linux_install"]),
    "3": ("Packages", ["deps", "linux_desktop", "both_packages"]),
    "4": ("Clean + packages", ["clean", "deps", "linux_desktop", "both_packages"]),
}


def fit(text, width):
    if width <= 0:
        return ""
    if len(text) <= width:
        return text
    return text[: max(0, width - 1)] + "…"


def draw_box(stdscr, y, x, h, w, title=""):
    if h < 2 or w < 2:
        return
    try:
        stdscr.addstr(y, x, "+" + "-" * (w - 2) + "+")
        for row in range(y + 1, y + h - 1):
            stdscr.addstr(row, x, "|")
            stdscr.addstr(row, x + w - 1, "|")
        stdscr.addstr(y + h - 1, x, "+" + "-" * (w - 2) + "+")
        if title:
            stdscr.addstr(y, x + 2, " " + fit(title, w - 6) + " ", curses.A_BOLD)
    except curses.error:
        pass


def write(stdscr, y, x, text, attr=0, width=None):
    try:
        if width is not None:
            text = fit(text, width)
        stdscr.addstr(y, x, text, attr)
    except curses.error:
        pass


def save_selection(selected):
    ordered = [item["key"] for item in OPTIONS if selected.get(item["key"], False)]
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump({"selected": ordered}, f, indent=2)


def main(stdscr):
    curses.curs_set(0)
    stdscr.keypad(True)
    try:
        curses.mousemask(curses.ALL_MOUSE_EVENTS | curses.REPORT_MOUSE_POSITION)
    except Exception:
        pass

    selected = dict(DEFAULT_SELECTED)
    cursor = 0
    offset = 0
    msg = "Enter starts build. Space toggles. Arrows move. Numbers toggle. P presets. Q quits."

    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()

        title = "Dosty Speak Linux builder"
        write(stdscr, 0, 2, title, curses.A_BOLD | curses.color_pair(0))
        write(stdscr, 1, 2, f"Version: {VERSION}", curses.A_DIM)
        write(stdscr, 2, 2, f"Log: {LOG_FILE}", curses.A_DIM, max(10, w - 4))

        left_w = min(max(42, w // 2), 68)
        right_x = left_w + 2
        right_w = max(20, w - right_x - 2)
        list_y = 5
        list_h = max(8, h - list_y - 5)

        draw_box(stdscr, list_y - 1, 1, list_h + 2, left_w, "Build options")

        visible_rows = list_h
        if cursor < offset:
            offset = cursor
        if cursor >= offset + visible_rows:
            offset = cursor - visible_rows + 1
        offset = max(0, min(offset, max(0, len(OPTIONS) - visible_rows)))

        current_group = None
        mouse_rows = {}
        row = list_y
        for idx in range(offset, min(len(OPTIONS), offset + visible_rows)):
            opt = OPTIONS[idx]
            if opt["group"] != current_group:
                current_group = opt["group"]
            marker = "[x]" if selected.get(opt["key"], False) else "[ ]"
            prefix = ">" if idx == cursor else " "
            attr = curses.A_REVERSE if idx == cursor else 0
            line = f"{prefix} {idx + 1:2d}) {marker} {opt['label']}"
            write(stdscr, row, 3, fit(line, left_w - 5), attr)
            mouse_rows[row] = idx
            row += 1

        if offset > 0:
            write(stdscr, list_y - 1, left_w - 6, "↑ more", curses.A_DIM)
        if offset + visible_rows < len(OPTIONS):
            write(stdscr, list_y + list_h, left_w - 6, "↓ more", curses.A_DIM)

        draw_box(stdscr, list_y - 1, right_x, list_h + 2, right_w, "Details")
        opt = OPTIONS[cursor]
        write(stdscr, list_y, right_x + 2, opt["label"], curses.A_BOLD, right_w - 4)
        write(stdscr, list_y + 1, right_x + 2, f"Group: {opt['group']}", curses.A_DIM, right_w - 4)
        desc_lines = textwrap.wrap(opt["desc"], width=max(10, right_w - 4))
        for i, line in enumerate(desc_lines[:5]):
            write(stdscr, list_y + 3 + i, right_x + 2, line, 0, right_w - 4)

        summary_y = list_y + 10
        if summary_y < list_y + list_h:
            write(stdscr, summary_y, right_x + 2, "Presets", curses.A_BOLD)
            p_y = summary_y + 1
            for key, (name, keys) in PRESETS.items():
                if p_y >= list_y + list_h:
                    break
                write(stdscr, p_y, right_x + 2, f"{key}) {name}", 0, right_w - 4)
                p_y += 1

        selected_count = sum(1 for v in selected.values() if v)
        footer_y = h - 3
        write(stdscr, footer_y, 2, fit(msg, w - 4), curses.A_DIM)
        write(stdscr, footer_y + 1, 2, f"Selected: {selected_count}   Enter build   Space toggle   A all/none   P presets   Q quit", curses.A_BOLD, w - 4)

        stdscr.refresh()
        ch = stdscr.getch()

        if ch in (ord("q"), ord("Q"), 27):
            with open(OUT_FILE, "w", encoding="utf-8") as f:
                json.dump({"selected": []}, f)
            return
        if ch in (curses.KEY_UP, ord("k")):
            cursor = max(0, cursor - 1)
        elif ch in (curses.KEY_DOWN, ord("j")):
            cursor = min(len(OPTIONS) - 1, cursor + 1)
        elif ch == curses.KEY_PPAGE:
            cursor = max(0, cursor - visible_rows)
        elif ch == curses.KEY_NPAGE:
            cursor = min(len(OPTIONS) - 1, cursor + visible_rows)
        elif ch in (ord(" "),):
            key = OPTIONS[cursor]["key"]
            selected[key] = not selected.get(key, False)
        elif ch in (10, 13, curses.KEY_ENTER):
            save_selection(selected)
            return
        elif ch in (ord("a"), ord("A")):
            all_on = all(selected.get(item["key"], False) for item in OPTIONS)
            for item in OPTIONS:
                selected[item["key"]] = not all_on
        elif ch in (ord("p"), ord("P")):
            msg = "Press preset number 1-4."
            stdscr.refresh()
            p = stdscr.getch()
            c = chr(p) if 0 <= p < 256 else ""
            if c in PRESETS:
                for item in OPTIONS:
                    selected[item["key"]] = False
                for key in PRESETS[c][1]:
                    selected[key] = True
                msg = f"Preset selected: {PRESETS[c][0]}"
        elif ord("1") <= ch <= ord("9"):
            idx = ch - ord("1")
            if 0 <= idx < len(OPTIONS):
                selected[OPTIONS[idx]["key"]] = not selected.get(OPTIONS[idx]["key"], False)
                cursor = idx
        elif ch == curses.KEY_MOUSE:
            try:
                _, mx, my, _, bstate = curses.getmouse()
                if my in mouse_rows:
                    cursor = mouse_rows[my]
                    if bstate & (curses.BUTTON1_CLICKED | curses.BUTTON1_PRESSED | curses.BUTTON1_RELEASED):
                        key = OPTIONS[cursor]["key"]
                        selected[key] = not selected.get(key, False)
            except Exception:
                pass


if __name__ == "__main__":
    curses.wrapper(main)
