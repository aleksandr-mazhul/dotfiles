#!/usr/bin/env python3
"""Simple GUI sudo askpass — forces EN layout on all Hyprland keyboards."""
import json
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib


def force_us_all() -> None:
    try:
        raw = subprocess.check_output(["hyprctl", "-j", "devices"], text=True)
        data = json.loads(raw)
    except Exception:
        return
    for kb in data.get("keyboards") or []:
        name = kb.get("name")
        if not name:
            continue
        subprocess.run(
            ["hyprctl", "switchxkblayout", name, "0"],
            check=False,
            capture_output=True,
        )


def active_layout() -> str:
    try:
        raw = subprocess.check_output(["hyprctl", "-j", "devices"], text=True)
        data = json.loads(raw)
        for kb in data.get("keyboards", []):
            if kb.get("main"):
                return str(kb.get("active_keymap") or "?")
    except Exception:
        pass
    return "?"


force_us_all()
layout = active_layout()
prompt = " ".join(sys.argv[1:]) or "Password:"

dialog = Gtk.MessageDialog(
    message_type=Gtk.MessageType.QUESTION,
    buttons=Gtk.ButtonsType.OK_CANCEL,
    text="Пароль sudo",
)
dialog.format_secondary_text(
    f"{prompt}\n\nРаскладка сейчас: {layout}\n"
    "Должна быть English (US). Если нет — переключи до ввода."
)
dialog.set_default_response(Gtk.ResponseType.OK)
dialog.set_keep_above(True)
box = dialog.get_message_area()
entry = Gtk.Entry()
entry.set_visibility(False)
entry.set_activates_default(True)
entry.set_hexpand(True)
box.add(entry)
dialog.show_all()
entry.grab_focus()


def keep_us():
    force_us_all()
    return True


GLib.timeout_add_seconds(1, keep_us)
resp = dialog.run()
text = entry.get_text() if resp == Gtk.ResponseType.OK else ""
dialog.destroy()
if resp == Gtk.ResponseType.OK:
    print(text)
    raise SystemExit(0)
raise SystemExit(1)
