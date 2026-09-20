#!/usr/bin/env bash
# Native Wayland Zoom on NVIDIA + Hyprland paints chrome but leaves
# meeting video and screen-share black. Force the X11/XWayland backend.
# Zoom rewrites zoomus.conf on exit, so pin xwayland=true on every start.
conf="${XDG_CONFIG_HOME:-$HOME/.config}/zoomus.conf"
if [[ -f "$conf" ]]; then
  if grep -q '^xwayland=' "$conf"; then
    sed -i 's/^xwayland=.*/xwayland=true/' "$conf"
  else
    sed -i '/^\[General\]/a xwayland=true' "$conf"
  fi
fi
export QT_QPA_PLATFORM=xcb
# Hyprland xwayland.force_zero_scaling: X11 windows are not compositor-scaled
# (sharp), so Zoom (Qt) must apply the DP-3 1.25 scale itself.
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_SCALE_FACTOR="${ZOOM_QT_SCALE:-1.25}"
unset QT_WAYLAND_SHELL_INTEGRATION
exec /usr/bin/zoom "$@"
