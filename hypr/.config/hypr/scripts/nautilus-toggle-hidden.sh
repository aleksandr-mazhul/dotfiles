#!/usr/bin/env bash
# Toggle Nautilus "show hidden files" (same setting Ctrl+H flips).
# Modern Nautilus has no custom keybinding API; Hyprland binds Ctrl+Shift+. here.
set -euo pipefail

schema="org.gtk.gtk4.Settings.FileChooser"
current="$(gsettings get "$schema" show-hidden 2>/dev/null || echo false)"
if [[ "$current" == "true" ]]; then
  next=false
else
  next=true
fi

gsettings set "$schema" show-hidden "$next"
# Keep legacy schema in sync (some GTK dialogs still read it)
gsettings set org.gtk.Settings.FileChooser show-hidden "$next" 2>/dev/null || true
# Deprecated nautilus key — still present on some builds
gsettings set org.gnome.nautilus.preferences show-hidden-files "$next" 2>/dev/null || true
