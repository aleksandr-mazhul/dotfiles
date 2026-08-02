#!/usr/bin/env python3
"""Per-window OS keyboard layout memory for Hyprland.

Each window keeps the layout you last used in it. Focus restores that layout.
eh-layout-sync mirrors OS → Ergohaven firmware so the keyboard stays aligned.

While the rice launcher forces EN (rice-launcher-kb-layout exists), this daemon
pauses mutations so temporary EN is not saved onto the focused app.
"""
from __future__ import annotations

import fcntl
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
LOCK_PATH = RUNTIME / "eh-window-layout.lock"
LAUNCHER_PAUSE = RUNTIME / "rice-launcher-kb-layout"
SIG = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")


def log(msg: str) -> None:
    print(f"[eh-window-layout] {msg}", file=sys.stderr, flush=True)


def layout_index(name: str) -> int:
    n = (name or "").lower()
    if "russian" in n or "русск" in n or n == "ru" or n.startswith("ru,"):
        return 1
    return 0


def hypr_devices() -> dict:
    return json.loads(subprocess.check_output(["hyprctl", "-j", "devices"], text=True))


def current_layout_index() -> int:
    data = hypr_devices()
    keyboards = data.get("keyboards") or []
    main = next((k for k in keyboards if k.get("main")), None)
    kb = main or (keyboards[0] if keyboards else None)
    if not kb:
        return 0
    return layout_index(str(kb.get("active_keymap") or ""))


def set_all_layouts(idx: int) -> None:
    data = hypr_devices()
    for kb in data.get("keyboards") or []:
        name = kb.get("name")
        if not name:
            continue
        low = str(name).lower()
        if "consumer-control" in low or "system-control" in low:
            continue
        subprocess.run(
            ["hyprctl", "switchxkblayout", name, str(idx)],
            check=False,
            capture_output=True,
        )


def normalize_addr(addr: str) -> str:
    a = (addr or "").strip().lower()
    if not a or a in ("0", "0x0"):
        return ""
    if a.startswith("0x"):
        return a
    try:
        return hex(int(a, 16))
    except ValueError:
        return a


def active_window_address() -> str:
    try:
        data = json.loads(
            subprocess.check_output(["hyprctl", "-j", "activewindow"], text=True)
        )
        return normalize_addr(str(data.get("address") or ""))
    except Exception:
        return ""


def acquire_lock():
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    fh = open(LOCK_PATH, "w", encoding="utf-8")
    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        fh.close()
        return None
    fh.write(str(os.getpid()))
    fh.flush()
    return fh


def socket2_path() -> Path:
    if not SIG:
        raise RuntimeError("HYPRLAND_INSTANCE_SIGNATURE is unset")
    return RUNTIME / "hypr" / SIG / ".socket2.sock"


def main() -> int:
    lock = acquire_lock()
    if lock is None:
        return 0

    layouts: dict[str, int] = {}
    prev = active_window_address()
    if prev:
        layouts[prev] = current_layout_index()
        log(f"seed {prev} → {layouts[prev]}")

    path = socket2_path()
    for _ in range(40):
        if path.is_socket():
            break
        time.sleep(0.25)
    if not path.is_socket():
        log(f"missing socket {path}")
        return 1

    log(f"watching {path}")

    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(str(path))
                buf = b""
                while True:
                    chunk = sock.recv(4096)
                    if not chunk:
                        raise ConnectionError("hypr socket closed")
                    buf += chunk
                    while b"\n" in buf:
                        raw, buf = buf.split(b"\n", 1)
                        line = raw.decode("utf-8", "replace").strip()
                        if not line:
                            continue
                        prev = handle_line(line, layouts, prev)
        except Exception as exc:
            log(f"reconnect: {exc}")
            time.sleep(0.5)


def handle_line(line: str, layouts: dict[str, int], prev: str) -> str:
    paused = LAUNCHER_PAUSE.exists()

    if line.startswith("activelayout>>"):
        if paused:
            return prev
        payload = line[len("activelayout>>") :]
        layout_name = payload.split(",", 1)[-1] if "," in payload else payload
        addr = prev or active_window_address()
        if addr:
            layouts[addr] = layout_index(layout_name)
        return prev

    if line.startswith("closewindow>>"):
        addr = normalize_addr(line[len("closewindow>>") :])
        layouts.pop(addr, None)
        return "" if prev == addr else prev

    if line.startswith("activewindowv2>>"):
        addr = normalize_addr(line[len("activewindowv2>>") :])
        if not addr:
            return ""

        if paused:
            return addr

        if prev and prev != addr:
            layouts[prev] = current_layout_index()

        if addr in layouts:
            want = layouts[addr]
            if want != current_layout_index():
                set_all_layouts(want)
                log(f"restore {addr} → {want}")
        else:
            layouts[addr] = current_layout_index()

        return addr

    return prev


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
