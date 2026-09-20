#!/usr/bin/env bash
# Calendar helpers for Quickshell (via khal + vdirsyncer).
#
# Independent vdirsyncer pairs — never share ~/.local/share/calendars/
# (iCloud uses collections = from a/from b; a foreign dir there would get
# discovered and pushed to Apple).
#   icloud -> ~/.local/share/calendars/<APPLE-UUID>/   (every Apple calendar; discovered)
#   gmap   -> ~/.local/share/calendars-gmap/gmap/      (map@ Gmail, writable)
#   gapm   -> ~/.local/share/calendars-gapm/gapm/      (apm@ Gmail, writable)
#   gamp   -> ~/.local/share/calendars-gamp/gamp/      (amp@ Gmail, writable)
# Each pair can be offline without breaking the others.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
KHAL="${KHAL:-khal}"
VDIR="${VDIRSYNCER:-vdirsyncer}"
PAIR="${VDIRSYNCER_PAIR:-icloud}"
PAIR_GMAP="${VDIRSYNCER_PAIR_GMAP:-gmap}"
PAIR_GAPM="${VDIRSYNCER_PAIR_GAPM:-gapm}"
PAIR_GAMP="${VDIRSYNCER_PAIR_GAMP:-gamp}"
CAL_ROOT="${HOME}/.local/share/calendars"
CAL_ROOT_GMAP="${HOME}/.local/share/calendars-gmap"
CAL_ROOT_GAPM="${HOME}/.local/share/calendars-gapm"
CAL_ROOT_GAMP="${HOME}/.local/share/calendars-gamp"
GMAP_DIR="gmap"
GAPM_DIR="gapm"
GAMP_DIR="gamp"
# Use khal's uv env so icalendar is available for edit/delete.
PY="${HOME}/.local/share/uv/tools/khal/bin/python"
[[ -x "$PY" ]] || PY="python3"

usage() {
  echo "usage: $0 days|events|colors|add|edit|delete|sync|calendars|watch ..." >&2
  exit 2
}

cmd="${1:-}"
[[ -n "$cmd" ]] || usage
shift || true

# Google pairs only. OAuth consent needs a browser, so the token is created once
# by hand (`vdirsyncer discover <pair>`). Until it exists, skip the pair outright:
# attempting it would burn the timeout on every `watch` tick and could block on an
# interactive prompt. After that, refreshes are silent and offline-safe.
sync_google_best_effort() {
  local pair="$1" root="$2" col="$3"
  [[ -s "${HOME}/.config/vdirsyncer/${pair}.token" ]] || return 0
  timeout -k 2 20 "$VDIR" sync "$pair" >/dev/null 2>&1 || true
  # displayname/color are metadata, not items; fetch them once.
  if [[ ! -s "${root}/${col}/color" ]]; then
    timeout -k 2 20 "$VDIR" metasync "$pair" >/dev/null 2>&1 || true
  fi
}

# Follow Apple Calendar: pick up calendars added there and drop the ones deleted.
# The pair uses `collections = ["from b"]`, so the remote list is authoritative and
# a stale local dir can no longer wedge the whole pair ("Not Found" -> every
# collection fails). `discover` is the only thing that refreshes that list.
# Throttled (watch ticks every 20 s); FORCE_DISCOVER=1 bypasses it.
ICLOUD_STATUS="${HOME}/.local/share/vdirsyncer/status"
DISCOVER_STAMP="${XDG_CACHE_HOME:-${HOME}/.cache}/qs-calendar-icloud-discover"
DISCOVER_EVERY=300

discover_icloud() {
  local now last=0
  now="$(date +%s)"
  [[ -f "$DISCOVER_STAMP" ]] && last="$(stat -c %Y "$DISCOVER_STAMP" 2>/dev/null || echo 0)"
  if [[ "${FORCE_DISCOVER:-0}" != 1 && $((now - last)) -lt "$DISCOVER_EVERY" \
        && -s "${ICLOUD_STATUS}/${PAIR}.collections" ]]; then
    return 0
  fi
  # `yes` only ever answers "create the missing LOCAL dir" (from-b pairs never
  # offer to create remote calendars).
  timeout -k 2 60 bash -c 'yes 2>/dev/null | "$0" discover "$1" >/dev/null 2>&1' "$VDIR" "$PAIR" || return 1
  mkdir -p "$(dirname "$DISCOVER_STAMP")" && touch "$DISCOVER_STAMP"
  # Orphans (deleted on Apple) go to calendars-trash/, never rm.
  CAL_ROOT="$CAL_ROOT" ICLOUD_STATUS="$ICLOUD_STATUS" PAIR="$PAIR" python3 - <<'PY'
import json, os, shutil, time
from pathlib import Path
root = Path(os.environ["CAL_ROOT"])
status = Path(os.environ["ICLOUD_STATUS"])
pair = os.environ["PAIR"]
try:
    keep = {c[0] for c in json.loads((status / f"{pair}.collections").read_text())["collections"]}
except Exception:
    raise SystemExit(0)
if not keep:  # never wipe everything because of an empty/failed listing
    raise SystemExit(0)
trash = root.parent / "calendars-trash"
stamp = time.strftime("%Y%m%d-%H%M%S")
for d in root.iterdir():
    if d.is_dir() and d.name not in keep:
        trash.mkdir(exist_ok=True)
        shutil.move(str(d), str(trash / f"{d.name}-{stamp}"))
        for f in (status / pair).glob(f"{d.name}.*"):
            shutil.move(str(f), str(trash / f"{f.name}-{stamp}"))
PY
  # displayname/color are metadata, not items: refresh so new/renamed/recoloured
  # calendars show up correctly.
  "$VDIR" metasync "$PAIR" >/dev/null 2>&1 || true
}

sync_now() {
  local rc=0
  discover_icloud || true
  "$VDIR" sync "$PAIR" >/dev/null 2>&1 || "$VDIR" sync "$PAIR" || rc=$?
  # Google pairs: isolated from iCloud. Token/network failures stay
  # best-effort so iCloud still completes.
  sync_google_best_effort "$PAIR_GMAP" "$CAL_ROOT_GMAP" "$GMAP_DIR"
  sync_google_best_effort "$PAIR_GAPM" "$CAL_ROOT_GAPM" "$GAPM_DIR"
  sync_google_best_effort "$PAIR_GAMP" "$CAL_ROOT_GAMP" "$GAMP_DIR"
  return "$rc"
}

# khal keeps a sqlite cache that can lag behind direct .ics edits
invalidate_khal() {
  rm -f "${HOME}/.local/share/khal/khal.db" \
        "${HOME}/.cache/khal/khal.db" 2>/dev/null || true
}

# Every calendar khal knows (iCloud is `type = discover`, so new Apple calendars
# appear here on their own) as JSON:
#   {"Домашний": {"path": ..., "color": "#34AADC", "readonly": false, "label": ..., "default": true}}
# Color: vdir `color` file (Apple/Google metadata) > khal config > fallback.
calmap() {
  "$PY" - <<'PY' 2>/dev/null
import json
from pathlib import Path
from khal.settings import get_config

# Calendars whose vdir has no color yet (first run, before metasync).
FALLBACK = {"gmap": "#3DBE7B", "gapm": "#00CFC1", "gamp": "#FF9F0A"}
LABEL = {"gmap": "Map", "gapm": "Apm", "gamp": "Amp"}
out, seen = {}, set()
cfg = get_config()
default = cfg["default"].get("default_calendar")
for name, c in cfg["calendars"].items():
    d = Path(c["path"])
    color = ""
    try:
        color = (d / "color").read_text().strip()
    except OSError:
        pass
    if not (color.startswith("#") and len(color) >= 7):
        color = c.get("color") or ""
    if not (color.startswith("#") and len(color) >= 7):
        color = FALLBACK.get(name, "")
    label = LABEL.get(name)
    if not label:
        try:
            label = (d / "displayname").read_text().strip()
        except OSError:
            label = ""
    label = label or name
    if label in seen:
        label = f"{label} ({name})"
    seen.add(label)
    out[name] = {"path": str(d), "color": color[:7], "readonly": bool(c.get("readonly")), "label": label, "default": name == default}
print(json.dumps(out, ensure_ascii=False))
PY
}

# calfield NAME FIELD -> value (empty if unknown)
calfield() {
  calmap | "$PY" -c 'import json,sys
o=json.load(sys.stdin).get(sys.argv[1]) or {}
v=o.get(sys.argv[2],"")
print("true" if v is True else "" if v is False else v)' "$1" "$2"
}

# Read-only calendars (khal `readonly = True`) mirror an upstream that would
# silently revert any write on the next sync.
reject_readonly() {
  if [[ "$(calfield "${1:-}" readonly)" == "true" ]]; then
    echo "«${1}» is read-only — it mirrors an upstream schedule." >&2
    exit 3
  fi
}

# Parse `khal list --json ...` (one JSON array per day) into events, dropping
# copies of the same event that live in several calendars (same UID and start).
# The read-only (authoritative) calendar wins, otherwise the first one seen.
KHAL_EVENTS_PY='
import json, os, sys
from collections import defaultdict
mode = sys.argv[1]
ro = {k for k, v in json.loads(os.environ["CALMAP"]).items() if v["readonly"]}
rows = []
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("[{"):
        continue
    try:
        arr = json.loads(line)
    except Exception:
        continue
    rows += [o for o in arr if o]
best = {}
for o in rows:
    k = (o.get("uid"), o.get("start-date"), o.get("start-time"))
    if not k[0]:
        continue
    cur = best.get(k)
    if cur is None or (o.get("calendar") in ro and cur.get("calendar") not in ro):
        best[k] = o
def keep(o):
    k = (o.get("uid"), o.get("start-date"), o.get("start-time"))
    return not k[0] or best[k] is o
rows = [o for o in rows if keep(o)]
if mode == "events":
    for o in rows:
        print(json.dumps(o, ensure_ascii=False))
else:
    days = defaultdict(list)
    for o in rows:
        d, cal = o.get("start-date") or "", o.get("calendar") or ""
        if len(d) >= 10 and cal:
            day = str(int(d[8:10]))
            if cal not in days[day]:
                days[day].append(cal)
    print(json.dumps(dict(days), ensure_ascii=False))
'

case "$cmd" in
  sync)
    FORCE_DISCOVER=1 sync_now
    invalidate_khal
    echo ok
    ;;

  calendars)
    # JSON: {"Домашний": {"path":..., "color":"#34AADC", "readonly":false, "label":"Домашний"}, ...}
    calmap
    ;;

  colors)
    # JSON: {"Домашний":"#34AADC","Рабочий":"#CB30E0",...}
    calmap | "$PY" -c 'import json,sys
print(json.dumps({k: v["color"] for k, v in json.load(sys.stdin).items() if v["color"]}, ensure_ascii=False))'
    ;;

  days)
    # JSON object: {"1":["Рабочий","Домашний"], "3":["Рабочий"]}
    month="${1:-}"
    [[ "$month" =~ ^[0-9]{4}-[0-9]{2}$ ]] || usage
    start="${month}-01"
    end="$(date -d "${start} +1 month -1 day" +%Y-%m-%d)"
    "$KHAL" list "$start" "$end" \
      --json start-date --json start-time --json uid --json calendar 2>/dev/null \
      | CALMAP="$(calmap)" "$PY" -c "$KHAL_EVENTS_PY" days
    ;;

  events)
    day="${1:-}"
    [[ "$day" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage
    "$KHAL" list "$day" "$day" \
      --json title \
      --json start-date \
      --json start-time \
      --json end-time \
      --json location \
      --json calendar \
      --json uid \
      2>/dev/null \
      | CALMAP="$(calmap)" "$PY" -c "$KHAL_EVENTS_PY" events
    ;;

  add)
    # add YYYY-MM-DD HH:MM HH:MM TITLE [LOCATION] [CALENDAR]
    # HH:MM may be "allday"
    day="${1:-}"; start="${2:-}"; end="${3:-}"; title="${4:-}"
    loc="${5:-}"; cal="${6:-}"
    [[ -n "$day" && -n "$start" && -n "$end" && -n "$title" ]] || usage
    reject_readonly "$cal"
    [[ -n "$cal" ]] || cal="$("$KHAL" printcalendars 2>/dev/null | head -1)"
    if [[ "$start" == "allday" || "$end" == "allday" ]]; then
      args=("$KHAL" new -a "$cal" "$day" "$title")
    else
      args=("$KHAL" new -a "$cal" "$day" "$start" "$end" "$title")
    fi
    [[ -n "$loc" ]] && args+=(-l "$loc")
    "${args[@]}" >/dev/null
    invalidate_khal
    sync_now
    echo ok
    ;;

  edit)
    # edit UID DAY START END TITLE LOCATION CALENDAR
    # START/END = HH:MM or allday
    uid="${1:-}"; day="${2:-}"; start="${3:-}"; end="${4:-}"
    title="${5:-}"; loc="${6:-}"; cal="${7:-}"
    [[ -n "$uid" && -n "$day" && -n "$start" && -n "$end" && -n "$title" && -n "$cal" ]] || usage
    reject_readonly "$cal"
    CALMAP="$(calmap)"
    EVENT_UID="$uid" DAY="$day" START="$start" END="$end" \
    TITLE="$title" LOC="$loc" CAL="$cal" CALMAP="$CALMAP" "$PY" - <<'PY'
import json, os, sys
from datetime import datetime, date, timedelta, timezone
from pathlib import Path
from icalendar import Calendar, vDatetime, vDate

cals = json.loads(os.environ["CALMAP"])
search_roots = [Path(c["path"]) for c in cals.values()]
readonly_roots = [Path(c["path"]) for c in cals.values() if c["readonly"]]
uid = os.environ["EVENT_UID"]
day = os.environ["DAY"]
start = os.environ["START"]
end = os.environ["END"]
title = os.environ["TITLE"]
loc = os.environ["LOC"]
cal_name = os.environ["CAL"]
if cal_name not in cals:
    sys.exit(f"unknown calendar: {cal_name}")
target_dir = Path(cals[cal_name]["path"])
if not target_dir.is_dir():
    sys.exit("missing calendar dir")

src = None
for base in search_roots:
    if not base.is_dir():
        continue
    for p in base.rglob("*.ics"):
        try:
            text = p.read_text(errors="ignore")
        except Exception:
            continue
        if uid in text:
            src = p
            break
    if src is not None:
        break
if src is None:
    sys.exit(f"event not found: {uid}")
if any(r in src.parents for r in readonly_roots):
    sys.exit("read-only calendar — it mirrors an upstream schedule.")

cal = Calendar.from_ical(src.read_bytes())
ev = None
for comp in cal.walk():
    if comp.name == "VEVENT" and str(comp.get("uid", "")).lower() == uid.lower():
        ev = comp
        break
if ev is None:
    sys.exit("vevent missing")

y, m, d = map(int, day.split("-"))
ev["summary"] = title
if loc:
    ev["location"] = loc
elif "location" in ev:
    del ev["location"]

if start == "allday" or end == "allday":
    ev["dtstart"] = vDate(date(y, m, d))
    ev["dtend"] = vDate(date(y, m, d) + timedelta(days=1))
else:
    sh, sm = map(int, start.split(":"))
    eh, em = map(int, end.split(":"))
    dt0 = datetime(y, m, d, sh, sm)
    dt1 = datetime(y, m, d, eh, em)
    if dt1 <= dt0:
        dt1 += timedelta(days=1)
    ev["dtstart"] = vDatetime(dt0)
    ev["dtend"] = vDatetime(dt1)

seq = int(ev.get("sequence", 0) or 0)
ev["sequence"] = seq + 1
ev["last-modified"] = vDatetime(datetime.now(timezone.utc).replace(tzinfo=None))
for key in ("dtstart", "dtend"):
    try:
        ev[key].params.clear()
    except Exception:
        pass

dest = target_dir / src.name
data = cal.to_ical()
if src.resolve() != dest.resolve():
    dest.write_bytes(data)
    src.unlink(missing_ok=True)
else:
    src.write_bytes(data)
print("ok")
PY
    invalidate_khal
    sync_now
    echo ok
    ;;

  delete)
    uid="${1:-}"
    [[ -n "$uid" ]] || usage
    EVENT_UID="$uid" CALMAP="$(calmap)" "$PY" - <<'PY'
import json, os, sys
from pathlib import Path
cals = json.loads(os.environ["CALMAP"])
search_roots = [Path(c["path"]) for c in cals.values()]
readonly_roots = [Path(c["path"]) for c in cals.values() if c["readonly"]]
uid = os.environ["EVENT_UID"]
src = None
for base in search_roots:
    if not base.is_dir():
        continue
    for p in base.rglob("*.ics"):
        try:
            text = p.read_text(errors="ignore")
        except Exception:
            continue
        if uid in text:
            src = p
            break
    if src is not None:
        break
if src is None:
    sys.exit(f"event not found: {uid}")
if any(r in src.parents for r in readonly_roots):
    sys.exit("read-only calendar — it mirrors an upstream schedule.")
src.unlink()
print("ok")
PY
    invalidate_khal
    sync_now
    echo ok
    ;;

  watch)
    # Poll remote every N seconds while this process runs (for open panel).
    # Prints "changed" on stdout when a sync actually pulled/pushed something.
    interval="${1:-20}"
    while true; do
      before="$(find "$CAL_ROOT" "$CAL_ROOT_GMAP" "$CAL_ROOT_GAPM" "$CAL_ROOT_GAMP" \( -name '*.ics' -o -name color -o -name displayname \) -printf '%T@ %p\n' 2>/dev/null | md5sum | awk '{print $1}')"
      sync_now || true
      after="$(find "$CAL_ROOT" "$CAL_ROOT_GMAP" "$CAL_ROOT_GAPM" "$CAL_ROOT_GAMP" \( -name '*.ics' -o -name color -o -name displayname \) -printf '%T@ %p\n' 2>/dev/null | md5sum | awk '{print $1}')"
      if [[ "$before" != "$after" ]]; then
        invalidate_khal
        echo changed
      fi
      sleep "$interval"
    done
    ;;

  *)
    usage
    ;;
esac
