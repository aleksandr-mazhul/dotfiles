#!/usr/bin/env bash
# One-time install: Adaptive SDDM login theme (needs your sudo password)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/themes/adaptive"
DST="/usr/share/sddm/themes/adaptive"
CACHE="${XDG_CONFIG_HOME:-$HOME/.config}/sddm-adaptive"
BIN="$ROOT/../bin/.local/bin"
[[ -x "$BIN/theme-render" ]] || BIN="$HOME/.local/bin"

# Wallpaper: explicit arg > current desktop wallpaper (hyprlock symlink, kept by
# apply-wallpaper-theme) > minimal-05 > first wallpaper found.
pick_wallpaper() {
  local w
  for w in "${1:-}" \
           "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lock-wallpaper" \
           "$HOME/pictures/wallpapers/minimal/minimal-05.jpg"; do
    [[ -n "$w" && -f "$w" ]] && { readlink -f "$w"; return; }
  done
  find "$HOME/pictures/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort | head -1 || true
}
WALL="$(pick_wallpaper "${1:-}")"

if [[ ! -d "$SRC" ]]; then
  echo "Theme source not found: $SRC" >&2
  exit 1
fi

echo "==> Installing Adaptive SDDM theme"
sudo mkdir -p /etc/sddm.conf.d
sudo rm -rf "$DST"
sudo mkdir -p "$DST"
sudo cp -a "$SRC"/. "$DST"/
sudo chown -R "$USER:$USER" "$DST"
sudo chmod 755 "$DST"
sudo find "$DST" -type f -exec chmod 644 {} \;

sudo cp -f "$ROOT/sddm.conf.d/10-adaptive-theme.conf" /etc/sddm.conf.d/10-adaptive-theme.conf

mkdir -p "$CACHE"
if [[ -n "$WALL" && -f "$WALL" ]]; then
  cp -f "$WALL" "$CACHE/background.jpg"
  cp -f "$WALL" "$DST/background.jpg"
fi

# Colors come from the theme SSOT (theme-render writes $CACHE/colors.conf).
# Never run matugen here: it would clobber SSOT-rendered configs.
if [[ -n "${1:-}" && -f "$1" && -x "$BIN/apply-wallpaper-theme" ]]; then
  # Explicit wallpaper: re-theme the desktop from it (also copies into $DST)
  "$BIN/apply-wallpaper-theme" "$WALL" || true
elif [[ -x "$BIN/theme-render" && -f "${XDG_CONFIG_HOME:-$HOME/.config}/theme/palette.toml" ]]; then
  # Keep the current desktop palette; just (re)render its consumers incl. sddm
  "$BIN/theme-render" >/dev/null || true
elif [[ -f "$WALL" && -x "$BIN/apply-wallpaper-theme" ]]; then
  "$BIN/apply-wallpaper-theme" "$WALL" || true
fi
if [[ -f "$CACHE/colors.conf" ]]; then
  cp -f "$CACHE/colors.conf" "$DST/colors.conf"
fi

echo
echo "OK. Theme: $DST"
echo "Conf:  /etc/sddm.conf.d/10-adaptive-theme.conf"
echo
echo "Preview:"
echo "  sddm-greeter-qt6 --test-mode --theme $DST"
echo
echo "Real view: log out or reboot to the login screen."
