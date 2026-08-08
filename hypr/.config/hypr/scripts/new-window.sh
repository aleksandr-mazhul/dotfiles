#!/usr/bin/env bash
# Open another window of the currently focused application (Ctrl+N).
set -euo pipefail

aw="$(hyprctl activewindow -j 2>/dev/null || true)"
[[ -z "${aw:-}" || "$aw" == "null" || "$aw" == "{}" ]] && exit 0

readarray -t meta < <(python3 -c '
import json, sys
w = json.loads(sys.stdin.read())
cls = (w.get("class") or w.get("initialClass") or "").strip()
pid = int(w.get("pid") or 0)
print(cls)
print(pid)
' <<<"$aw")

class="${meta[0]:-}"
pid="${meta[1]:-0}"
[[ -z "$class" ]] && exit 0

# Explicit new-window commands for apps that need special flags / single-instance quirks.
case "${class,,}" in
  kitty)
    exec kitty
    ;;
  cursor)
    # VS Code / Cursor: -n = new window
    if command -v cursor >/dev/null; then
      exec cursor -n
    fi
    exec "$HOME/Applications/Cursor.AppImage" -n
    ;;
  firefox)
    exec firefox --new-window
    ;;
  org.gnome.nautilus|nautilus)
    exec "$HOME/.local/bin/nautilus-dark" --new-window
    ;;
  org.telegram.desktop|telegramdesktop)
    exec Telegram
    ;;
esac

# Resolve a .desktop entry by WM class / app id, then launch it.
desktop="$(CLASS="$class" python3 - <<'PY'
import os
from pathlib import Path

cls = os.environ.get("CLASS", "")
cls_l = cls.lower()
dirs = [
    Path.home() / ".local/share/applications",
    Path("/usr/local/share/applications"),
    Path("/usr/share/applications"),
]

def parse(path: Path):
    data = {}
    try:
        text = path.read_text(errors="ignore")
    except OSError:
        return data
    for line in text.splitlines():
        if "=" not in line or line.startswith("#"):
            continue
        k, _, v = line.partition("=")
        data.setdefault(k.strip(), v.strip())
    return data

best = None
best_score = -1
for d in dirs:
    if not d.is_dir():
        continue
    for path in d.glob("*.desktop"):
        e = parse(path)
        if e.get("NoDisplay", "").lower() in ("1", "true"):
            continue
        wm = (e.get("StartupWMClass") or "").lower()
        icon = (e.get("Icon") or "").lower()
        stem = path.stem.lower()
        score = 0
        if wm and wm == cls_l:
            score = 100
        elif stem == cls_l:
            score = 90
        elif icon == cls_l:
            score = 80
        elif wm and (wm in cls_l or cls_l in wm):
            score = 60
        elif stem in cls_l or cls_l in stem:
            score = 40
        if score > best_score:
            best_score = score
            best = path

print(best if best and best_score >= 40 else "")
PY
)"

if [[ -n "${desktop:-}" ]]; then
  if command -v gtk-launch >/dev/null; then
    id="$(basename "$desktop" .desktop)"
    exec gtk-launch "$id"
  fi
  exec gio launch "$desktop"
fi

# Last resort: re-exec the focused process binary (no args).
if [[ "$pid" -gt 1 && -x "/proc/$pid/exe" ]]; then
  exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
  if [[ -n "$exe" && -x "$exe" ]]; then
    exec "$exe"
  fi
fi

exit 0
