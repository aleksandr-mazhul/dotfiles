#!/usr/bin/env bash
# Toggle Nautilus "show hidden files" (Finder-style Ctrl+Shift+.).
# Nautilus 50 watches org.gnome.nautilus.preferences show-hidden-files.
set -euo pipefail

nautilus_schema="org.gnome.nautilus.preferences"
raw="$(gsettings get "$nautilus_schema" show-hidden-files 2>/dev/null || echo false)"
raw="${raw//\'/}"
raw="${raw//\"/}"

if [[ "$raw" == "true" ]]; then
  next=false
else
  next=true
fi

gsettings set "$nautilus_schema" show-hidden-files "$next"
gsettings set org.gtk.gtk4.Settings.FileChooser show-hidden "$next" 2>/dev/null || true
gsettings set org.gtk.Settings.FileChooser show-hidden "$next" 2>/dev/null || true
