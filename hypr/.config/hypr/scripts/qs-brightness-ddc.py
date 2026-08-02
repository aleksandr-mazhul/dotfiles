#!/usr/bin/env python3
"""Raw DDC/CI brightness for rice (nouveau-friendly, multi-monitor).

Auto-discovers every /dev/i2c-* bus that answers VCP 0x10 (brightness)
and applies the same percentage to all of them.

Usage:
  qs-brightness-ddc.py get|set <0-100>|max|list|target|picture realistic
"""
from __future__ import annotations

import fcntl
import glob
import os
import sys
import time

I2C_SLAVE = 0x0703
DDC_ADDR = 0x37
VCP_BRIGHTNESS = 0x10
VCP_CONTRAST = 0x12
VCP_COLOR_PRESET = 0x14  # 01h=sRGB, 05h=6500K, …

CACHE_DIR = os.environ.get("XDG_RUNTIME_DIR") or os.path.join(
    os.environ.get("HOME", "/tmp"), ".cache"
)
BUS_LIST_CACHE = os.path.join(CACHE_DIR, "rice-ddc-buses")  # "2,5"
MAX_CACHE = os.path.join(CACHE_DIR, "rice-ddc-max")  # global UI max (=100)


def xor_sum(init: int, data: bytes) -> int:
    c = init
    for b in data:
        c ^= b
    return c & 0xFF


def open_bus(n: int) -> int:
    fd = os.open(f"/dev/i2c-{n}", os.O_RDWR)
    try:
        fcntl.ioctl(fd, I2C_SLAVE, DDC_ADDR)
    except OSError:
        os.close(fd)
        raise
    return fd


def ddc_write(fd: int, payload: list[int]) -> None:
    body = bytes(payload)
    os.write(fd, body + bytes([xor_sum(0x6E, body)]))


def parse_get(data: bytes, code: int) -> tuple[int, int] | None:
    # 6E 88 02 rc vcp type max_hi max_lo cur_hi cur_lo chk
    if len(data) < 11:
        return None
    if data[3] != 0:  # unsupported / error
        return None
    if data[4] != code:
        return None
    mx = (data[6] << 8) | data[7]
    cur = (data[8] << 8) | data[9]
    if mx <= 0:
        return None
    return cur, mx


def get_vcp(n: int, code: int) -> tuple[int, int] | None:
    fd = open_bus(n)
    try:
        ddc_write(fd, [0x51, 0x82, 0x01, code])
        time.sleep(0.045)
        return parse_get(os.read(fd, 16), code)
    finally:
        os.close(fd)


def set_vcp(n: int, code: int, raw: int, mx: int) -> None:
    raw = max(0, min(int(mx), int(raw)))
    fd = open_bus(n)
    try:
        hi, lo = (raw >> 8) & 0xFF, raw & 0xFF
        ddc_write(fd, [0x51, 0x84, 0x03, code, hi, lo])
        time.sleep(0.03)
    finally:
        os.close(fd)


def bus_name(n: int) -> str:
    try:
        with open(f"/sys/class/i2c-dev/i2c-{n}/name", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def candidate_buses() -> list[int]:
    buses: list[int] = []
    for p in glob.glob("/dev/i2c-*"):
        tail = os.path.basename(p).split("-")[1]
        if tail.isdigit():
            buses.append(int(tail))
    named = [(n, bus_name(n)) for n in buses]
    # Prefer display connectors; still try others (except obvious SMBus) as fallback.
    named.sort(
        key=lambda t: (
            0 if t[1].startswith(("DP-", "HDMI", "DVI", "eDP")) else 1,
            2 if "SMBus" in t[1] or "I801" in t[1] else 0,
            t[0],
        )
    )
    return [n for n, name in named if "SMBus" not in name and "I801" not in name]


def probe_bus(n: int) -> tuple[int, int] | None:
    """Return (cur, max) for brightness if this bus has a DDC monitor."""
    for attempt in range(3):
        try:
            got = get_vcp(n, VCP_BRIGHTNESS)
            if got:
                return got
            return None
        except OSError as e:
            # nouveau often returns EBUSY briefly on unused/contended ports
            if getattr(e, "errno", None) == 16 and attempt < 2:
                time.sleep(0.05 * (attempt + 1))
                continue
            return None
    return None


def write_text(path: str, text: str) -> None:
    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    except OSError:
        pass


def read_text(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return None


def discover_all(force: bool = False) -> list[tuple[int, int, int]]:
    """Return list of (bus, cur, max) for every answering monitor."""
    cached = read_text(BUS_LIST_CACHE)
    out: list[tuple[int, int, int]] = []

    if cached and not force:
        ok = True
        for part in cached.split(","):
            part = part.strip()
            if not part.isdigit():
                continue
            n = int(part)
            got = probe_bus(n)
            if not got:
                ok = False
                break
            out.append((n, got[0], got[1]))
        if ok and out:
            return out
        out = []

    for n in candidate_buses():
        got = probe_bus(n)
        if got:
            out.append((n, got[0], got[1]))

    if out:
        write_text(BUS_LIST_CACHE, ",".join(str(b) for b, _, _ in out))
        # UI scale is always 0–100; per-monitor max used only for raw mapping.
        write_text(MAX_CACHE, "100")
    return out


def apply_realistic_picture(n: int, brightness_pct: int = 65) -> None:
    """Comfortable / accurate picture: factory-ish contrast, natural white point.

    Previously we cranked contrast to 100 whenever brightness hit 100 — that made
    the panel look blown-out and harsh on the eyes. Never do that again.

    Color preset (VCP 0x14): prefer sRGB (1); fall back to 6500K (5). Apply
    preset *before* contrast/brightness — some panels reset those on mode change.
    """
    # Color preset first
    try:
        got = get_vcp(n, VCP_COLOR_PRESET)
        if got:
            cur, mx = got
            if mx >= 1:
                # Try sRGB; if the panel ignores it, use 6500K (D65).
                set_vcp(n, VCP_COLOR_PRESET, 1, mx)
                time.sleep(0.08)
                after = get_vcp(n, VCP_COLOR_PRESET)
                if after and after[0] != 1 and mx >= 5:
                    set_vcp(n, VCP_COLOR_PRESET, 5, mx)
                    time.sleep(0.08)
    except OSError:
        pass

    # Contrast → ~50% of max (M27Q factory default)
    try:
        got = get_vcp(n, VCP_CONTRAST)
        if got:
            _cur, mx = got
            if mx > 0:
                set_vcp(n, VCP_CONTRAST, int(round(mx * 0.5)), mx)
                time.sleep(0.05)
    except OSError:
        pass

    # Brightness last so mode/contrast changes can't wipe it
    try:
        got = get_vcp(n, VCP_BRIGHTNESS)
        if got:
            _cur, mx = got
            if mx > 0:
                raw = int(round(max(0, min(100, brightness_pct)) * mx / 100.0))
                set_vcp(n, VCP_BRIGHTNESS, raw, mx)
    except OSError:
        pass


def selected_mons(mons: list[tuple[int, int, int]]) -> list[tuple[int, int, int]]:
    """Filter by rice-ddc-target: 'all' (default) or a bus number."""
    target = (read_text(os.path.join(CACHE_DIR, "rice-ddc-target")) or "all").strip().lower()
    if target in ("", "all", "*"):
        return mons
    if target.isdigit():
        want = int(target)
        hit = [m for m in mons if m[0] == want]
        return hit if hit else mons
    return mons


def friendly_label(n: int) -> str:
    name = bus_name(n)
    if name.startswith(("DP-", "HDMI-", "DVI-", "eDP-")):
        return f"Monitor ({name})"
    if name:
        return name
    return f"Display i2c-{n}"


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "get"

    if cmd == "max":
        print(100)
        return 0

    if cmd == "target":
        # qs-brightness-ddc.py target all|2
        val = (sys.argv[2] if len(sys.argv) > 2 else "all").strip().lower()
        if val not in ("all", "*") and not val.isdigit():
            print("usage: target all|<bus>", file=sys.stderr)
            return 2
        if val == "*":
            val = "all"
        write_text(os.path.join(CACHE_DIR, "rice-ddc-target"), val)
        print(val)
        return 0

    if cmd == "list":
        mons = discover_all(force=True)
        target = (read_text(os.path.join(CACHE_DIR, "rice-ddc-target")) or "all").strip().lower()
        all_sel = "1" if target in ("", "all", "*") else "0"
        print(f"all|All monitors|{all_sel}")
        for bus, cur, mx in mons:
            sel = "1" if target == str(bus) else "0"
            print(f"{bus}|{friendly_label(bus)}|{sel}")
        return 0

    if cmd == "picture":
        # qs-brightness-ddc.py picture realistic [brightness%]
        mode = (sys.argv[2] if len(sys.argv) > 2 else "realistic").strip().lower()
        pct = int(sys.argv[3]) if len(sys.argv) > 3 else 65
        if mode not in ("realistic", "srgb", "reset"):
            print("usage: picture realistic|srgb|reset [brightness%]", file=sys.stderr)
            return 2
        mons = discover_all(force=True)
        mons = selected_mons(mons)
        if not mons:
            print("no-ddc", file=sys.stderr)
            return 1
        for bus, _cur, _mx in mons:
            apply_realistic_picture(bus, pct)
        print(pct)
        return 0

    mons = discover_all(force=(cmd == "get"))
    if not mons:
        print("no-ddc", file=sys.stderr)
        return 1
    mons = selected_mons(mons)
    if not mons:
        print("no-ddc", file=sys.stderr)
        return 1

    if cmd == "get":
        pcts = [int(round(cur * 100.0 / mx)) for _, cur, mx in mons if mx]
        print(min(pcts) if pcts else 0)
        return 0

    if cmd == "set":
        if len(sys.argv) < 3:
            print("usage: set <0-100>", file=sys.stderr)
            return 2
        pct = max(0, min(100, int(sys.argv[2])))
        for bus, _cur, mx in mons:
            raw = int(round(pct * mx / 100.0))
            if pct >= 100:
                raw = mx
            try:
                set_vcp(bus, VCP_BRIGHTNESS, raw, mx)
            except OSError:
                time.sleep(0.05)
                try:
                    set_vcp(bus, VCP_BRIGHTNESS, raw, mx)
                except OSError as e:
                    print(f"bus {bus}: {e}", file=sys.stderr)
        print(pct)
        return 0

    print("usage: get|set <n>|max|list|target|picture realistic", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
