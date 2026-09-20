"""Ctrl+V that pastes text like kitty does, but hands an image clipboard to the app.

Claude Code attaches a clipboard image when it receives a raw ^V (via wl-paste), while
kitty's own paste_from_clipboard only handles text. Bound in kitty.conf as
`map ctrl+v kitten smart_paste.py`.
"""
import subprocess
from typing import Any, List

from kittens.tui.handler import result_handler
from kitty.clipboard import get_clipboard_string


def main(args: List[str]) -> str:
    return ''


def clipboard_is_image_only() -> bool:
    try:
        out = subprocess.run(['wl-paste', '--list-types'], capture_output=True, text=True, timeout=1).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    types = out.split()
    return any(t.startswith('image/') for t in types) and not any(t.startswith('text/') for t in types)


@result_handler(no_ui=True)
def handle_result(args: List[str], answer: str, target_window_id: int, boss: Any) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    if clipboard_is_image_only():
        w.write_to_child(b'\x16')
        return
    if w.send_paste_event():
        return
    text = get_clipboard_string()
    if text:
        w.paste_with_actions(text)
