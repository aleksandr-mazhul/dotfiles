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
unset QT_WAYLAND_SHELL_INTEGRATION
exec /usr/bin/zoom "$@"
