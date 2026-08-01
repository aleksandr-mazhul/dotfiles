#!/usr/bin/env bash
# One-time install: Adaptive SDDM login theme (needs your sudo password)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/themes/adaptive"
DST="/usr/share/sddm/themes/adaptive"
CACHE="${XDG_CONFIG_HOME:-$HOME/.config}/sddm-adaptive"
WALL="${1:-$HOME/Pictures/Wallpapers/minimal/minimal-05.jpg}"

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
if [[ -f "$WALL" ]]; then
  cp -f "$WALL" "$CACHE/background.jpg"
  cp -f "$WALL" "$DST/background.jpg"
fi

if command -v matugen >/dev/null 2>&1 && [[ -f "$WALL" ]]; then
  matugen image "$WALL" --mode dark --type scheme-tonal-spot --prefer saturation || true
  if [[ -f "$CACHE/colors.conf" ]]; then
    cp -f "$CACHE/colors.conf" "$DST/colors.conf"
  fi
fi

echo
echo "OK. Theme: $DST"
echo "Conf:  /etc/sddm.conf.d/10-adaptive-theme.conf"
echo
echo "Preview:"
echo "  sddm-greeter-qt6 --test-mode --theme $DST"
echo
echo "Real view: log out or reboot to the login screen."
