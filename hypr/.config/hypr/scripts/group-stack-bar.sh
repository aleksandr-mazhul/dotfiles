#!/usr/bin/env bash
# JSON for rice GroupStackBar — screen-local coords (account for reserved bar zone).
python3 - <<'PY'
import json, subprocess, sys

def j(cmd):
    return json.loads(subprocess.check_output(["hyprctl", "-j", cmd], text=True))

def norm(a):
    s = str(a or "").lower()
    return s[2:] if s.startswith("0x") else s

try:
    aw = j("activewindow")
except Exception:
    print("{}")
    sys.exit(0)

grouped = aw.get("grouped") or []
if not grouped or aw.get("fullscreen"):
    print("{}")
    sys.exit(0)

addr = norm(aw.get("address"))
gset = {norm(a) for a in grouped}
clients = j("clients")
members = [c for c in clients if {norm(a) for a in (c.get("grouped") or [])} & gset]
if not members:
    print("{}")
    sys.exit(0)

order = {norm(a): i for i, a in enumerate(grouped)}
members.sort(key=lambda c: order.get(norm(c.get("address")), 999))

at = aw.get("at") or [0, 0]
size = aw.get("size") or [0, 0]
mon_id = aw.get("monitor")
monitors = j("monitors")
mon = next((m for m in monitors if m.get("id") == mon_id), None) or next(
    (m for m in monitors if m.get("focused")), monitors[0]
)

mon_x = int(mon.get("x") or 0)
mon_y = int(mon.get("y") or 0)
# reserved: [left, top, right, bottom] — layer surfaces sit below the bar reserve
reserved = mon.get("reserved") or [0, 0, 0, 0]
res_l = int(reserved[0] if len(reserved) > 0 else 0)
res_t = int(reserved[1] if len(reserved) > 1 else 0)

# decoration.rounding = 10; small gap between strip and window top edge
rounding = 10
gap = 6
h = 3
seg_gap = 3

# Global strip geometry (just above the window frame)
gx = int(at[0]) + rounding
gy = int(at[1]) - gap - h
total_w = max(0, int(size[0]) - 2 * rounding)
n = len(members)
seg_w = (total_w - seg_gap * max(0, n - 1)) / n if n else 0

# Convert to PanelWindow-local: origin is (monX+resL, monY+resT)
segs = []
for i, c in enumerate(members):
    segs.append({
        "x": gx + i * (seg_w + seg_gap) - mon_x - res_l,
        "y": gy - mon_y - res_t,
        "w": max(2.0, seg_w),
        "h": h,
        "active": norm(c.get("address")) == addr,
        "address": c.get("address") or "",
    })

print(json.dumps({"segments": segs}))
PY
