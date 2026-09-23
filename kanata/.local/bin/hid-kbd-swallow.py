#!/usr/bin/env python3
"""Grab extra HID keyboard nodes so Hyprland never sees them.

Kanata already grabs the real keyboards (see kanata.kbd linux-dev). Ergohaven
still exposes a second "Keyboard" interface; Hyprland treats it as another
keyboard and one tap becomes several characters. EVIOCGRAB here swallows those
nodes without feeding them into kanata (which would double-process).

Only a "* Keyboard" node that shares vendor:product with a kanata-owned device
is swallowed, so on another machine an ordinary "Foo USB Keyboard" is left
alone. Devices are rescanned every few seconds: a replug re-creates the node,
and the old fd is dropped when a read reports it gone.
"""
from __future__ import annotations

import array
import errno
import fcntl
import os
import select
import signal
import sys
from pathlib import Path

EVIOCGRAB = 0x40044590
EVENT_SIZE = 24
RESCAN_SECONDS = 3.0

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


def should_swallow(name: str, usb_id: str, owned_ids: set[str]) -> bool:
    if name in KANATA_OWNED:
        return False
    if "Consumer Control" in name or "System Control" in name:
        return False
    return name.endswith(" Keyboard") and usb_id in owned_ids


def kbd_devices() -> list[tuple[str, str, str]]:
    """(event path, name, "vendor:product") for every node with a kbd handler."""
    raw = Path("/proc/bus/input/devices").read_text(errors="replace")
    out: list[tuple[str, str, str]] = []
    for block in raw.split("\n\n"):
        name = ""
        handlers = ""
        usb_id = ""
        for line in block.splitlines():
            if line.startswith("N: Name="):
                name = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("H: Handlers="):
                handlers = line.split("=", 1)[1]
            elif line.startswith("I: "):
                f = dict(kv.split("=", 1) for kv in line[3:].split() if "=" in kv)
                usb_id = f"{f.get('Vendor', '')}:{f.get('Product', '')}"
        if "kbd" not in handlers:
            continue
        ev = next((part for part in handlers.split() if part.startswith("event")), None)
        if ev:
            out.append((f"/dev/input/{ev}", name, usb_id))
    return out


def node_id(path: str) -> tuple[str, int] | None:
    """A replugged device can reuse the path; the node's ctime tells them apart."""
    try:
        st = os.stat(path)
    except OSError:
        return None
    return (path, st.st_ctime_ns)


def main() -> int:
    grabbed: dict[int, tuple[tuple[str, int], str]] = {}
    seen: set[tuple[str, int]] = set()

    def release(fd: int) -> None:
        try:
            fcntl.ioctl(fd, EVIOCGRAB, 0)
        except OSError:
            pass
        try:
            os.close(fd)
        except OSError:
            pass

    def cleanup(*_args: object) -> None:
        for fd in list(grabbed):
            release(fd)
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    def scan() -> None:
        devices = kbd_devices()
        owned_ids = {usb_id for _, name, usb_id in devices if name in KANATA_OWNED}
        held = {nid for nid, _ in grabbed.values()}
        for path, name, usb_id in devices:
            nid = node_id(path)
            if nid is None:
                continue
            new = nid not in seen
            seen.add(nid)
            if name in KANATA_OWNED:
                if new:
                    disable_kernel_repeat(path)
                continue
            if nid in held or not should_swallow(name, usb_id, owned_ids):
                continue
            disable_kernel_repeat(path)
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                fcntl.ioctl(fd, EVIOCGRAB, 1)
            except OSError as err:
                print(f"skip {name} ({path}): {err}", flush=True)
                continue
            grabbed[fd] = (nid, name)
            print(f"swallowed: {name} ({path})", flush=True)

    scan()
    while True:
        # A removed device stays "readable" forever and read() fails with
        # ENODEV; swallowing that error used to spin this loop at 100% CPU.
        ready, _, _ = select.select(list(grabbed), [], [], RESCAN_SECONDS)
        lost = False
        for fd in ready:
            try:
                os.read(fd, EVENT_SIZE * 64)
            except BlockingIOError:
                pass
            except OSError as err:
                (_, name) = grabbed.pop(fd)
                release(fd)
                lost = True
                print(f"released: {name} ({errno.errorcode.get(err.errno, err)})", flush=True)
        if lost or not ready:
            scan()


if __name__ == "__main__":
    raise SystemExit(main())
