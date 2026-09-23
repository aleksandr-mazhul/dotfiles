"""Super+H/L: jump between nvim's file tree and code window, but only when
nvim is actually the foreground process in the focused kitty window.

`send_text` used to fire this blindly at whatever window had focus, so a
plain shell would receive the raw `<C-\\><C-n>:lua Focus...()<CR>` as literal
text and choke on it (`fish: Unknown command: :lua`). Bound in kitty.conf as
`map super+h kitten focus_nvim_pane.py tree` / `... code`.
"""
from typing import Any, List

from kittens.tui.handler import result_handler

FUNCS = {'tree': 'FocusFileTree', 'code': 'FocusCodeWindow'}


def main(args: List[str]) -> str:
    return ''


@result_handler(no_ui=True)
def handle_result(args: List[str], answer: str, target_window_id: int, boss: Any) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None or w.child is None:
        return
    which = args[1] if len(args) > 1 else ''
    cmdline = w.child.foreground_cmdline
    if not cmdline or 'nvim' not in cmdline[0]:
        # Not nvim (e.g. tmux): forward Alt-h/Alt-l, which tmux's
        # vim-tmux-navigator bindings route to a pane or into nvim.
        seq = {'tree': b'\x1bh', 'code': b'\x1bl'}.get(which)
        if seq:
            w.write_to_child(seq)
        return
    fn = FUNCS.get(which)
    if not fn:
        return
    w.write_to_child(f'\x1c\x0e:lua {fn}()\r'.encode())
