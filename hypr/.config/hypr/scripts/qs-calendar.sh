#!/usr/bin/env bash
# Apple iCloud calendar helpers for Quickshell (via khal + vdirsyncer).
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
KHAL="${KHAL:-khal}"
VDIR="${VDIRSYNCER:-vdirsyncer}"
PAIR="${VDIRSYNCER_PAIR:-icloud}"
CAL_ROOT="${HOME}/.local/share/calendars"
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

sync_now() {
  "$VDIR" sync "$PAIR" >/dev/null 2>&1 || "$VDIR" sync "$PAIR"
}

# khal keeps a sqlite cache that can lag behind direct .ics edits
invalidate_khal() {
  rm -f "${HOME}/.local/share/khal/khal.db" \
        "${HOME}/.cache/khal/khal.db" 2>/dev/null || true
}

# Map khal calendar name -> collection dir basename
cal_dir() {
  case "$1" in
    home) echo "9AD6A905-4394-4DEB-A541-0EDD26673817" ;;
    work) echo "D45EDFFB-6C51-450C-81B2-0F118203646B" ;;
    uni) echo "C7CC8CE1-F42A-45F3-94DE-CE07E400E009" ;;
    reminders) echo "3cb67dc0-4d6c-40eb-91d3-424f48c70a3a" ;;
    *) return 1 ;;
  esac
}

dir_to_cal() {
  case "$1" in
    9AD6A905-4394-4DEB-A541-0EDD26673817) echo home ;;
    D45EDFFB-6C51-450C-81B2-0F118203646B) echo work ;;
    C7CC8CE1-F42A-45F3-94DE-CE07E400E009) echo uni ;;
    3cb67dc0-4d6c-40eb-91d3-424f48c70a3a) echo reminders ;;
    *) echo unknown ;;
  esac
}

read_color() {
  local d="$1" c
  c="$(tr -d '\n' <"${d}/color" 2>/dev/null || true)"
  # Apple stores #RRGGBBAA — strip alpha for QML
  if [[ "$c" =~ ^#[0-9A-Fa-f]{8}$ ]]; then
    echo "${c:0:7}"
  elif [[ "$c" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
    echo "$c"
  else
    echo ""
  fi
}

case "$cmd" in
  sync)
    sync_now
    invalidate_khal
    echo ok
    ;;

  calendars)
    "$KHAL" printcalendars 2>/dev/null
    ;;

  colors)
    # JSON: {"home":"#34AADC","work":"#CB30E0",...}
    python3 - <<PY
import json, pathlib
root = pathlib.Path("${CAL_ROOT}")
mapping = {
  "9AD6A905-4394-4DEB-A541-0EDD26673817": "home",
  "D45EDFFB-6C51-450C-81B2-0F118203646B": "work",
  "C7CC8CE1-F42A-45F3-94DE-CE07E400E009": "uni",
  "3cb67dc0-4d6c-40eb-91d3-424f48c70a3a": "reminders",
}
fallback = {"home":"#34AADC","work":"#CB30E0","uni":"#0088FF","reminders":"#B14BC9"}
out = dict(fallback)
for uid, name in mapping.items():
    p = root / uid / "color"
    if p.is_file():
        c = p.read_text().strip()
        if len(c) >= 7 and c.startswith("#"):
            out[name] = c[:7]
print(json.dumps(out, ensure_ascii=False))
PY
    ;;

  days)
    # JSON object: {"1":["work","home"], "3":["work"]}
    month="${1:-}"
    [[ "$month" =~ ^[0-9]{4}-[0-9]{2}$ ]] || usage
    start="${month}-01"
    end="$(date -d "${start} +1 month -1 day" +%Y-%m-%d)"
    "$KHAL" list "$start" "$end" \
      --json start-date --json calendar 2>/dev/null \
      | "$PY" -c '
import json, sys
from collections import defaultdict
days = defaultdict(list)
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("[{"):
        continue
    try:
        arr = json.loads(line)
    except Exception:
        continue
    for o in arr:
        if not o:
            continue
        d = o.get("start-date") or ""
        cal = o.get("calendar") or ""
        if len(d) >= 10 and cal:
            day = str(int(d[8:10]))
            if cal not in days[day]:
                days[day].append(cal)
print(json.dumps(dict(days), ensure_ascii=False))
'
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
      | while IFS= read -r line; do
          [[ "$line" == \[{* ]] || continue
          "$PY" -c 'import json,sys
arr=json.loads(sys.argv[1])
for o in arr:
  if o: print(json.dumps(o, ensure_ascii=False))
' "$line"
        done
    ;;

  add)
    # add YYYY-MM-DD HH:MM HH:MM TITLE [LOCATION] [CALENDAR]
    # HH:MM may be "allday"
    day="${1:-}"; start="${2:-}"; end="${3:-}"; title="${4:-}"
    loc="${5:-}"; cal="${6:-home}"
    [[ -n "$day" && -n "$start" && -n "$end" && -n "$title" ]] || usage
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
    title="${5:-}"; loc="${6:-}"; cal="${7:-home}"
    [[ -n "$uid" && -n "$day" && -n "$start" && -n "$end" && -n "$title" ]] || usage
    EVENT_UID="$uid" DAY="$day" START="$start" END="$end" \
    TITLE="$title" LOC="$loc" CAL="$cal" CAL_ROOT="$CAL_ROOT" "$PY" - <<'PY'
import os, sys
from datetime import datetime, date, timedelta, timezone
from pathlib import Path
from icalendar import Calendar, vDatetime, vDate

root = Path(os.environ["CAL_ROOT"])
uid = os.environ["EVENT_UID"]
day = os.environ["DAY"]
start = os.environ["START"]
end = os.environ["END"]
title = os.environ["TITLE"]
loc = os.environ["LOC"]
cal_name = os.environ["CAL"]
mapping = {
    "home": "9AD6A905-4394-4DEB-A541-0EDD26673817",
    "work": "D45EDFFB-6C51-450C-81B2-0F118203646B",
    "uni": "C7CC8CE1-F42A-45F3-94DE-CE07E400E009",
    "reminders": "3cb67dc0-4d6c-40eb-91d3-424f48c70a3a",
}
target_dir = root / mapping.get(cal_name, mapping["home"])
if not target_dir.is_dir():
    sys.exit("missing calendar dir")

src = None
for p in root.rglob("*.ics"):
    try:
        text = p.read_text(errors="ignore")
    except Exception:
        continue
    if uid in text:
        src = p
        break
if src is None:
    sys.exit(f"event not found: {uid}")

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
    EVENT_UID="$uid" CAL_ROOT="$CAL_ROOT" "$PY" - <<'PY'
import os, sys
from pathlib import Path
root = Path(os.environ["CAL_ROOT"])
uid = os.environ["EVENT_UID"]
src = None
for p in root.rglob("*.ics"):
    try:
        text = p.read_text(errors="ignore")
    except Exception:
        continue
    if uid in text:
        src = p
        break
if src is None:
    sys.exit(f"event not found: {uid}")
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
      before="$(find "$CAL_ROOT" -name '*.ics' -printf '%T@ %p\n' 2>/dev/null | md5sum | awk '{print $1}')"
      sync_now || true
      after="$(find "$CAL_ROOT" -name '*.ics' -printf '%T@ %p\n' 2>/dev/null | md5sum | awk '{print $1}')"
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
