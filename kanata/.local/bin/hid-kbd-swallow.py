#!/usr/bin/env python3
"""Grab extra HID keyboard nodes so Hyprland never sees them.

Kanata already grabs the real keyboards (see kanata.kbd linux-dev). Ergohaven
still exposes a second "Keyboard" interface; Hyprland treats it as another
keyboard and one tap becomes several characters. EVIOCGRAB here swallows those
nodes without feeding them into kanata (which would double-process).
"""
from __future__ import annotations

import array
import fcntl
import os
import select
import signal
import sys
import time
from pathlib import Path

EVIOCGRAB = 0x40044590
EVENT_SIZE = 24

KANATA_OWNED = {
    "Ergohaven K:03 v3/v4",
    "Compx VGN Dragonfly 4K Receiver",
    "SEMICO USB Gaming Keyboard",
    "kanata",
}


def _ioctl_iow(type_: str, nr: int, size: int) -> int:
    return 1 << 30 | size << 16 | ord(type_) << 8 | nr


EVIOCSREP = _ioctl_iow("E", 0x03, 8)


def disable_kernel_repeat(path: str) -> None:
    """Stop evdev autorepeat so a ~250ms second tap is not turned into extra chars."""
    try:
        fd = os.open(path, os.O_RDWR)
    except OSError:
        return
    try:
        fcntl.ioctl(fd, EVIOCSREP, array.array("i", [0, 0]))
    except OSError:
        pass
    finally:
        os.close(fd)


def should_swallow(name: str) -> bool:
    if name in KANATA_OWNED:
        return False
    if "Consumer Control" in name or "System Control" in name:
        return False
    return name.endswith(" Keyboard")


def kbd_devices() -> list[tuple[str, str]]:
    raw = Path("/proc/bus/input/devices").read_text(errors="replace")
    out: list[tuple[str, str]] = []
    for block in raw.split("\n\n"):
        name = ""
        handlers = ""
        for line in block.splitlines():
            if line.startswith("N: Name="):
                name = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("H: Handlers="):
                handlers = line.split("=", 1)[1]
        if "kbd" not in handlers:
            continue
        ev = None
        for part in handlers.split():
            if part.startswith("event"):
                ev = part
                break
        if ev:
            out.append((f"/dev/input/{ev}", name))
    return out


def main() -> int:
    grabbed: list[int] = []

    def cleanup(*_args: object) -> None:
        for fd in grabbed:
            try:
                fcntl.ioctl(fd, EVIOCGRAB, 0)
            except OSError:
                pass
            try:
                os.close(fd)
            except OSError:
                pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    while True:
        for path, name in kbd_devices():
            if name in KANATA_OWNED:
                disable_kernel_repeat(path)
                continue
            if not should_swallow(name):
                continue
            disable_kernel_repeat(path)
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                fcntl.ioctl(fd, EVIOCGRAB, 1)
            except OSError as err:
                print(f"skip {name} ({path}): {err}", flush=True)
                continue
            grabbed.append(fd)
            print(f"swallowed: {name} ({path})", flush=True)
        if grabbed:
            break
        print("no extra kbd nodes yet; retrying", flush=True)
        time.sleep(1)

    print(f"holding {len(grabbed)} grabs", flush=True)
    while True:
        ready, _, _ = select.select(grabbed, [], [], 60.0)
        for fd in ready:
            try:
                os.read(fd, EVENT_SIZE * 64)
            except (BlockingIOError, OSError):
                pass


if __name__ == "__main__":
    raise SystemExit(main())
