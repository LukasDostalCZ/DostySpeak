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
    {"key": "deps", "group": "Setup", "label": "Install/check dependencies", "desc": "Checks Homebrew tools, Qt, Android helper tools, SDK/NDK and Xcode status."},

    {"key": "mac_desktop", "group": "macOS desktop", "label": "Build and install macOS desktop app", "desc": "Builds the full desktop macOS app and installs it into ~/Applications."},
    {"key": "mac_package", "group": "macOS desktop", "label": "Create macOS desktop ZIP/DMG in dist", "desc": "Creates desktop release ZIP and DMG in dist."},

    {"key": "mobile_preview", "group": "Mobile preview", "label": "Build mobile preview for this Mac", "desc": "Builds the touch/mobile preview app for local testing on this Mac."},
    {"key": "run_mobile_preview", "group": "Mobile preview", "label": "Run mobile preview after build", "desc": "Launches the mobile preview in the background so the builder can continue."},
    {"key": "mobile_package", "group": "Mobile preview", "label": "Create mobile preview ZIP", "desc": "Creates a ZIP with the mobile preview app."},

    {"key": "android", "group": "Android", "label": "Build Android APK", "desc": "Builds Android APK, detects SDK/NDK/Qt Android kit and signs a debug APK."},
    {"key": "android_install", "group": "Android", "label": "Install Android APK to connected phone", "desc": "Installs the latest signed APK from dist/android using adb."},
    {"key": "android_log", "group": "Android", "label": "Capture Android crash log", "desc": "Installs/starts the Android app and saves logcat crash logs into logs."},

    {"key": "qt_ios", "group": "iPhone / iPad", "label": "Install/check Qt iOS kit", "desc": "Tries to install the Qt iOS kit, or opens Qt Maintenance Tool and waits for manual component selection."},
    {"key": "ios_prepare", "group": "iPhone / iPad", "label": "Prepare iPhone install in Xcode", "desc": "Checks Xcode/Qt iOS, generates the Xcode project and opens Xcode for signing and iPhone install."},
    {"key": "ios", "group": "iPhone / iPad", "label": "Build iOS app / Xcode project", "desc": "Builds iOS app/Xcode project when Xcode and Qt iOS kit are present."},
]

DEFAULT_SELECTED = {
    "deps": True,
    "mac_desktop": True,
    "mac_package": True,
    "mobile_preview": False,
    "run_mobile_preview": False,
    "mobile_package": False,
    "android": False,
    "android_install": False,
    "android_log": False,
    "qt_ios": False,
    "ios_prepare": False,
    "ios": False,
}

PRESETS = {
    "1": ("Desktop release", ["deps", "mac_desktop", "mac_package"]),
    "2": ("Android debug", ["deps", "android", "android_install", "android_log"]),
    "3": ("iPhone prep", ["deps", "qt_ios", "ios_prepare"]),
    "4": ("Everything useful", ["deps", "mac_desktop", "mac_package", "mobile_preview", "android", "qt_ios", "ios_prepare"]),
}


def fit(text, width):
    if width <= 0:
        return ""
    text = str(text)
    if len(text) <= width:
        return text
    return text[: max(0, width - 1)] + "…"


def add_safe(stdscr, y, x, text, attr=0):
    h, w = stdscr.getmaxyx()
    if y < 0 or y >= h or x >= w:
        return
    if x < 0:
        text = text[-x:]
        x = 0
    try:
        stdscr.addstr(y, x, fit(text, max(0, w - x - 1)), attr)
    except curses.error:
        pass


def draw_box(stdscr, y, x, h, w, title=""):
    if h < 3 or w < 4:
        return
    attr = curses.color_pair(4)
    add_safe(stdscr, y, x, "┌" + "─" * (w - 2) + "┐", attr)
    for yy in range(y + 1, y + h - 1):
        add_safe(stdscr, yy, x, "│", attr)
        add_safe(stdscr, yy, x + w - 1, "│", attr)
    add_safe(stdscr, y + h - 1, x, "└" + "─" * (w - 2) + "┘", attr)
    if title:
        add_safe(stdscr, y, x + 2, f" {title} ", curses.color_pair(3) | curses.A_BOLD)


def write_result(selected):
    data = {"selected": [opt["key"] for opt in OPTIONS if selected.get(opt["key"], False)]}
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f)


def option_rows():
    rows = []
    last_group = None
    for i, opt in enumerate(OPTIONS):
        if opt["group"] != last_group:
            rows.append(("group", opt["group"], None))
            last_group = opt["group"]
        rows.append(("option", opt, i))
    return rows


def selected_count(selected):
    return sum(1 for opt in OPTIONS if selected.get(opt["key"], False))


def main(stdscr):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.start_color()
    curses.init_pair(1, curses.COLOR_CYAN, -1)
    curses.init_pair(2, curses.COLOR_BLACK, curses.COLOR_WHITE)
    curses.init_pair(3, curses.COLOR_YELLOW, -1)
    curses.init_pair(4, curses.COLOR_BLUE, -1)
    curses.init_pair(5, curses.COLOR_GREEN, -1)
    curses.init_pair(6, curses.COLOR_RED, -1)
    curses.init_pair(7, curses.COLOR_MAGENTA, -1)

    try:
        curses.mousemask(curses.ALL_MOUSE_EVENTS | curses.REPORT_MOUSE_POSITION)
    except Exception:
        pass

    selected = dict(DEFAULT_SELECTED)
    cursor = 0
    scroll = 0
    message = "Presety: 1 desktop, 2 android, 3 iPhone, 4 vše užitečné."

    rows = option_rows()

    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()

        if h < 22 or w < 76:
            add_safe(stdscr, 0, 0, "Terminál je moc malý. Zvětši ho aspoň na 76×22.", curses.color_pair(6) | curses.A_BOLD)
            add_safe(stdscr, 2, 0, "q = konec")
            key = stdscr.getch()
            if key in (ord("q"), ord("Q")):
                write_result({})
                return
            continue

        add_safe(stdscr, 1, 2, "Dosty Speak — macOS terminal builder", curses.color_pair(1) | curses.A_BOLD)
        add_safe(stdscr, 2, 2, f"Version: {VERSION}", curses.A_BOLD)
        add_safe(stdscr, 3, 2, "↑/↓ j/k: pohyb   Space: vybrat   Enter: build   1/2/3/4: preset   a: vše   n: nic   l: logy   q: konec")
        add_safe(stdscr, 4, 2, f"Selected: {selected_count(selected)}   Log: {LOG_FILE}")

        left_w = min(72, max(48, w // 2 + 4))
        right_x = left_w + 4
        right_w = w - right_x - 2
        top = 6
        list_h = h - 12
        visible_rows = max(5, list_h - 2)

        draw_box(stdscr, top, 2, list_h, left_w, "Build options")
        draw_box(stdscr, top, right_x, list_h, right_w, "Detail")

        # keep cursor visible in scroll window
        cursor_row = next((idx for idx, row in enumerate(rows) if row[0] == "option" and row[2] == cursor), 0)
        if cursor_row < scroll:
            scroll = cursor_row
        elif cursor_row >= scroll + visible_rows:
            scroll = cursor_row - visible_rows + 1
        scroll = max(0, min(scroll, max(0, len(rows) - visible_rows)))

        shown = rows[scroll:scroll + visible_rows]
        for screen_i, row in enumerate(shown):
            y = top + 1 + screen_i
            if row[0] == "group":
                add_safe(stdscr, y, 4, f"── {row[1]} ", curses.color_pair(7) | curses.A_BOLD)
                continue

            opt = row[1]
            opt_index = row[2]
            mark = "●" if selected.get(opt["key"], False) else "○"
            prefix = "➜" if opt_index == cursor else " "
            line = f"{prefix} {mark} {opt['label']}"
            attr = curses.color_pair(2) | curses.A_BOLD if opt_index == cursor else 0
            add_safe(stdscr, y, 4, line, attr)

        if scroll > 0:
            add_safe(stdscr, top + 1, left_w - 3, "▲", curses.color_pair(3))
        if scroll + visible_rows < len(rows):
            add_safe(stdscr, top + list_h - 2, left_w - 3, "▼", curses.color_pair(3))

        current = OPTIONS[cursor]
        add_safe(stdscr, top + 2, right_x + 2, current["label"], curses.A_BOLD | curses.color_pair(1))
        add_safe(stdscr, top + 3, right_x + 2, f"Group: {current['group']}", curses.color_pair(7))
        add_safe(stdscr, top + 4, right_x + 2, "Selected: " + ("yes" if selected.get(current["key"], False) else "no"), curses.color_pair(5 if selected.get(current["key"], False) else 6))

        wrapped = textwrap.wrap(current["desc"], max(20, right_w - 4))
        for idx, line in enumerate(wrapped[: max(1, list_h - 11)]):
            add_safe(stdscr, top + 6 + idx, right_x + 2, line)

        preset_y = top + list_h - 4
        if preset_y > top + 8:
            add_safe(stdscr, preset_y, right_x + 2, "Presets:", curses.A_BOLD)
            add_safe(stdscr, preset_y + 1, right_x + 2, "1 Desktop   2 Android   3 iPhone   4 Useful all")

        summary_y = h - 5
        draw_box(stdscr, summary_y, 2, 3, w - 4, "Summary")
        chosen = [opt["label"] for opt in OPTIONS if selected.get(opt["key"], False)]
        summary = ", ".join(chosen) if chosen else "Nothing selected."
        add_safe(stdscr, summary_y + 1, 4, summary, curses.color_pair(5 if chosen else 6))

        add_safe(stdscr, h - 1, 2, message, curses.color_pair(3))
        stdscr.refresh()

        key = stdscr.getch()

        if key in (curses.KEY_UP, ord("k"), ord("K")):
            cursor = (cursor - 1) % len(OPTIONS)
            message = ""
        elif key in (curses.KEY_DOWN, ord("j"), ord("J")):
            cursor = (cursor + 1) % len(OPTIONS)
            message = ""
        elif key in (curses.KEY_NPAGE,):
            cursor = min(len(OPTIONS) - 1, cursor + max(1, visible_rows - 2))
        elif key in (curses.KEY_PPAGE,):
            cursor = max(0, cursor - max(1, visible_rows - 2))
        elif key in (ord(" "),):
            selected[OPTIONS[cursor]["key"]] = not selected.get(OPTIONS[cursor]["key"], False)
            message = ""
        elif key in (10, 13, curses.KEY_ENTER):
            write_result(selected)
            return
        elif key in (ord("q"), ord("Q")):
            write_result({})
            return
        elif key in (ord("a"), ord("A")):
            any_off = any(not selected.get(opt["key"], False) for opt in OPTIONS)
            for opt in OPTIONS:
                selected[opt["key"]] = any_off
            message = "Vybráno vše." if any_off else "Vše odznačeno."
        elif key in (ord("n"), ord("N")):
            for opt in OPTIONS:
                selected[opt["key"]] = False
            message = "Vše odznačeno."
        elif key in (ord("l"), ord("L")):
            try:
                os.system(f'open "{os.path.dirname(LOG_FILE)}" >/dev/null 2>&1 &')
                message = "Otevřena složka logů."
            except Exception:
                message = "Log folder nejde otevřít."
        elif chr(key) in PRESETS if 0 <= key <= 255 else False:
            preset_name, keys = PRESETS[chr(key)]
            for opt in OPTIONS:
                selected[opt["key"]] = opt["key"] in keys
            message = f"Preset: {preset_name}"
            # move cursor to first selected option
            for idx, opt in enumerate(OPTIONS):
                if opt["key"] in keys:
                    cursor = idx
                    break
        elif key == curses.KEY_MOUSE:
            try:
                _, mx, my, _, bstate = curses.getmouse()
                if 2 <= mx < 2 + left_w and top + 1 <= my < top + 1 + visible_rows:
                    row_idx = scroll + (my - (top + 1))
                    if 0 <= row_idx < len(rows) and rows[row_idx][0] == "option":
                        cursor = rows[row_idx][2]
                        selected[OPTIONS[cursor]["key"]] = not selected.get(OPTIONS[cursor]["key"], False)
                        message = ""
            except Exception:
                pass


if __name__ == "__main__":
    curses.wrapper(main)
