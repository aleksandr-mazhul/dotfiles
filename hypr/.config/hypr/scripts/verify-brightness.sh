#!/usr/bin/env bash
# One-shot: fix ddcutil perms, verify brightness, reload rice.
set +e
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -d /run/user/$(id -u)/hypr ]]; then
  export HYPRLAND_INSTANCE_SIGNATURE="$(ls /run/user/$(id -u)/hypr | head -1)"
fi

echo "== user $(id -un) groups: $(groups) =="
echo "== /dev/i2c =="
ls -l /dev/i2c-* 2>&1

echo
echo "== fix ddcutil cache ownership =="
if [[ -d "$HOME/.cache/ddcutil" ]]; then
  if [[ ! -w "$HOME/.cache/ddcutil" ]]; then
    sudo chown -R "$USER:$USER" "$HOME/.cache/ddcutil"
  fi
fi
mkdir -p "$HOME/.cache/ddcutil" "$HOME/.cache/rice"

echo
echo "== ddcutil detect =="
ddcutil detect
echo
echo "== current brightness =="
ddcutil getvcp 10 --brief
echo
SCRIPT="$HOME/.config/hypr/scripts/qs-brightness.sh"
chmod +x "$SCRIPT" 2>/dev/null
echo "script get: $($SCRIPT get)"
echo "script set 60: $($SCRIPT set 60)"
sleep 0.4
echo "script get: $($SCRIPT get)"
echo "script set 75: $($SCRIPT set 75)"

echo
echo "== reload hypr + qs =="
hyprctl reload
qs -c rice ipc call theme reload
sleep 0.5
echo "done"
echo
echo "Открой Quick Settings (сетка) — ползунок яркости над громкостью."
echo "Enter — закрыть"
read -r
