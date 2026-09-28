#!/usr/bin/env bash
# apply-wallpaper-theme must record the chosen image where waypaper --restore
# will read it, and point the hyprlock symlink at the same file.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/bin/.local/bin/apply-wallpaper-theme"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
mkdir -p "$home/pictures" "$home/.config/waypaper" "$home/.local/state"
img="$home/pictures/picked.png"
printf 'png' >"$img"
other="$home/pictures/other.png"
printf 'png' >"$other"

cat >"$home/.config/waypaper/config.ini" <<'EOF'
[Settings]
language = ru
folder = ~/pictures
wallpaper = ~/pictures/other.png
    ~/pictures/picked.png
backend = swww
monitors = All
use_xdg_state = False
post_command = ~/.local/bin/apply-wallpaper-theme $wallpaper
EOF

run_remember() {
  HOME="$home" \
  XDG_CONFIG_HOME="$home/.config" \
  XDG_STATE_HOME="$home/.local/state" \
  XDG_RUNTIME_DIR="$tmp/run" \
  WAYLAND_DISPLAY="" \
    "$script" --remember-only "$1"
}
mkdir -p "$tmp/run"

run_remember "$img"

ini="$home/.config/waypaper/config.ini"
grep -qx 'wallpaper = ~/pictures/picked.png' "$ini"
# Multiline continuation of the previous value must not survive.
if grep -Eq '^[[:space:]]+~/pictures/' "$ini"; then
  echo "stale multiline wallpaper left in config" >&2
  cat "$ini" >&2
  exit 1
fi
grep -qx 'backend = swww' "$ini"
grep -qx 'post_command = ~/.local/bin/apply-wallpaper-theme $wallpaper' "$ini"
target="$(readlink -f "$home/.config/hypr/lock-wallpaper")"
[[ "$target" == "$(readlink -f "$img")" ]]

# use_xdg_state keeps the path in state.ini and leaves config.ini alone.
cat >"$home/.config/waypaper/config.ini" <<'EOF'
[Settings]
wallpaper = ~/pictures/other.png
use_xdg_state = True
EOF
run_remember "$img"
grep -qx 'wallpaper = ~/pictures/other.png' "$home/.config/waypaper/config.ini"
grep -qx 'wallpaper = ~/pictures/picked.png' "$home/.local/state/waypaper/state.ini"

# Missing key is inserted inside [Settings], not after a later section.
cat >"$home/.config/waypaper/config.ini" <<'EOF'
[Settings]
language = ru
use_xdg_state = False

[Other]
kept = yes
EOF
run_remember "$other"
awk '
  /^\[Other\]/ { in_other=1 }
  in_other && /^wallpaper = / { bad=1 }
  END { exit bad }
' "$home/.config/waypaper/config.ini"
grep -qx 'wallpaper = ~/pictures/other.png' "$home/.config/waypaper/config.ini"
grep -qx 'kept = yes' "$home/.config/waypaper/config.ini"

# A symlink inside the wallpaper folder is stored as that symlink, not its target.
mkdir -p "$home/pictures/linked" "$tmp/outside"
printf 'png' >"$tmp/outside/real.png"
ln -s "$tmp/outside/real.png" "$home/pictures/linked/alias.png"
cat >"$home/.config/waypaper/config.ini" <<'EOF'
[Settings]
wallpaper = ~/pictures/other.png
use_xdg_state = False
EOF
run_remember "$home/pictures/linked/alias.png"
grep -qx 'wallpaper = ~/pictures/linked/alias.png' "$home/.config/waypaper/config.ini"
link_target="$(readlink "$home/.config/hypr/lock-wallpaper")"
[[ "$link_target" == "$home/pictures/linked/alias.png" ]]

echo "ok"
