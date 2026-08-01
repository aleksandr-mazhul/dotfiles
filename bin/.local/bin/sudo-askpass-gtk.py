#!/usr/bin/env python3
"""Simple GUI sudo askpass — shows current keyboard layout."""
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib
import subprocess

def active_layout() -> str:
    try:
        import json
        raw = subprocess.check_output(["hyprctl", "-j", "devices"], text=True)
        data = json.loads(raw)
        for kb in data.get("keyboards", []):
            if kb.get("main"):
                return str(kb.get("active_keymap") or "?")
    except Exception:
        pass
    return "?"

# Force US before dialog
try:
    subprocess.run(
        ["hyprctl", "switchxkblayout", "ergohaven-k:03-v3/v4", "0"],
        check=False,
        capture_output=True,
    )
except Exception:
    pass

layout = active_layout()
prompt = " ".join(__import__("sys").argv[1:]) or "Password:"

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
box = dialog.get_message_area()
entry = Gtk.Entry()
entry.set_visibility(False)
entry.set_activates_default(True)
entry.set_hexpand(True)
box.add(entry)
dialog.show_all()

# keep layout glued to US while dialog open
def keep_us():
    try:
        subprocess.run(
            ["hyprctl", "switchxkblayout", "ergohaven-k:03-v3/v4", "0"],
            check=False,
            capture_output=True,
        )
    except Exception:
        pass
    return True

GLib.timeout_add_seconds(1, keep_us)
resp = dialog.run()
text = entry.get_text() if resp == Gtk.ResponseType.OK else ""
dialog.destroy()
if resp == Gtk.ResponseType.OK:
    print(text)
    raise SystemExit(0)
raise SystemExit(1)
