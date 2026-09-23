#!/usr/bin/env bash
# One-command restore for this rice on a fresh Arch system.
#
# Usage (from a clone of this repo):
#   ./bootstrap.sh              # full: packages + restow + services + theme
#   ./bootstrap.sh --rice       # curated packages only
#   ./bootstrap.sh --configs    # skip package install; only restow/services/theme
#
# Prerequisites: Arch Linux, network, sudo. Run in a real terminal (password prompts).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

mode="${1:-all}"
DO_PKGS=1
PKG_ARGS=()
case "$mode" in
  --rice|rice) PKG_ARGS=(--rice) ;;
  --configs|configs) DO_PKGS=0 ;;
  all|"") ;;
  -h|--help|help)
    sed -n '2,12p' "$0"
    exit 0
    ;;
  *)
    echo "Unknown option: $mode (try --help)" >&2
    exit 2
    ;;
esac

log() { printf '\n==> %s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

install_yay_if_needed() {
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi
  log "Installing yay (AUR helper)"
  sudo pacman -S --needed --noconfirm base-devel git
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2164
  git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
}

if [[ "$DO_PKGS" -eq 1 ]]; then
  need_cmd sudo
  need_cmd pacman
  install_yay_if_needed
  log "Installing packages"
  # install.sh skips unknown names and reports failed builds (exit 1) instead
  # of aborting midway; carry on to restow either way.
  "$ROOT/packages/install.sh" "${PKG_ARGS[@]:-}" \
    || echo "warn: some packages failed to install (see the summary above)" >&2
fi

# swww was renamed awww in the Arch repos (same author, same CLI); the scripts
# still call swww / swww-daemon.
mkdir -p "$HOME/.local/bin"
for pair in swww:awww swww-daemon:awww-daemon; do
  old="${pair%%:*}" new="${pair##*:}"
  if ! command -v "$old" >/dev/null 2>&1 && command -v "$new" >/dev/null 2>&1; then
    ln -s "$(command -v "$new")" "$HOME/.local/bin/$old"
  fi
done

if ! command -v stow >/dev/null 2>&1; then
  log "Installing stow"
  need_cmd sudo
  sudo pacman -S --needed --noconfirm stow
fi
need_cmd stow
log "Restowing dotfiles into \$HOME"
"$ROOT/restow.sh"
# The default restow never writes into the repo, so a dirty tree here means
# tracked files were changed (e.g. by --adopt) and need a look.
if ! git -C "$ROOT" diff --quiet 2>/dev/null; then
  echo "warn: tracked files in $ROOT changed — review: git -C $ROOT diff" >&2
fi

log "Device access (uinput for kanata, i2c for ddcutil, video for backlight)"
# kanata-setup.sh: uinput module + udev rule + input group (sudo, idempotent).
if [[ -x "$ROOT/kanata/.local/bin/kanata-setup.sh" ]]; then
  "$ROOT/kanata/.local/bin/kanata-setup.sh" || echo "warn: kanata-setup.sh failed" >&2
fi
{
  echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null &&
    { sudo modprobe i2c-dev || true; } &&
    { getent group i2c >/dev/null || sudo groupadd --system i2c; } &&
    sudo usermod -aG video,i2c "$USER"
} || echo "warn: i2c/video group setup failed" >&2

log "System files (/etc: udev rules, zram, docker socket)"
"$ROOT/system/install.sh" || echo "warn: system/install.sh failed" >&2

if command -v tmux >/dev/null 2>&1; then
  log "tmux plugins (tpm)"
  tpm="$HOME/.tmux/plugins/tpm"
  if [[ ! -d "$tpm" ]]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm" \
      || echo "warn: tpm clone failed" >&2
  fi
  if [[ -x "$tpm/bin/install_plugins" ]]; then
    "$tpm/bin/install_plugins" || echo "warn: tpm install_plugins failed" >&2
  fi
fi

if [[ -x "$HOME/.config/hypr/scripts/ocr-install.sh" ]]; then
  log "Screen OCR (RapidOCR en+ru)"
  "$HOME/.config/hypr/scripts/ocr-install.sh" || echo "warn: OCR venv install failed" >&2
fi

log "User services"
systemctl --user daemon-reload || true
# Every unit this repo ships that is enabled on the reference machine.
# hid-kbd-swallow only grabs "* Keyboard" siblings of a kanata-owned device, so
# on a machine without those keyboards it idles.
for unit in kanata.service hid-kbd-swallow.service tmux-save.service icloud-calendar-sync.timer \
  vscode-cursor-sync.path vscode-cursor-sync-idle.timer cursor-update.timer; do
  [[ -f "$HOME/.config/systemd/user/$unit" ]] || continue
  systemctl --user enable --now "$unit" || {
    case "$unit" in
      kanata.service)
        echo "warn: $unit failed to start (run kanata-setup.sh: uinput + input group; re-login)" >&2 ;;
      *) echo "warn: $unit failed to enable" >&2 ;;
    esac
  }
done
# QS draws notifications; swaync would steal the D-Bus name if activated.
systemctl --user mask swaync.service 2>/dev/null || true

if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish)" ]] \
  && command -v fish >/dev/null 2>&1; then
  log "Setting fish as login shell (may prompt for password)"
  chsh -s "$(command -v fish)" || echo "warn: chsh failed; set shell manually" >&2
fi

log "Theme SSOT"
if [[ -x "$HOME/.local/bin/apply-wallpaper-theme" ]]; then
  wall=""
  if [[ -n "${BOOTSTRAP_WALLPAPER:-}" && -f "${BOOTSTRAP_WALLPAPER}" ]]; then
    wall="$BOOTSTRAP_WALLPAPER"
  else
    wall="$(find "$HOME/pictures/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | head -1 || true)"
  fi
  if [[ -n "$wall" ]]; then
    "$HOME/.local/bin/apply-wallpaper-theme" "$wall" || true
  elif [[ -x "$HOME/.local/bin/theme-render" && -f "$HOME/.config/theme/palette.toml" ]]; then
    "$HOME/.local/bin/theme-render" || true
  else
    echo "warn: no wallpaper found under ~/pictures/wallpapers — run apply-wallpaper-theme later" >&2
  fi
fi

if [[ -x "$HOME/.local/bin/vscode-cursor-sync" ]] && command -v code >/dev/null 2>&1; then
  log "VS Code / Cursor settings + extensions"
  "$HOME/.local/bin/vscode-cursor-sync" || echo "warn: vscode-cursor-sync failed" >&2
fi

if [[ -x "$ROOT/sddm/install.sh" ]]; then
  log "SDDM adaptive theme (optional; needs sudo)"
  "$ROOT/sddm/install.sh" || echo "warn: SDDM install skipped/failed" >&2
fi

cat <<'EOF'

============================================================
Bootstrap finished.

Restored automatically:
  • packages (repo + AUR + required lists, hw-*.txt for the detected GPU/CPU)
  • uinput/udev + input, i2c, video groups; tmux plugins via tpm
  • all stowed configs (Hypr, Kitty, Fish, Kanata, Tmux, nvim, QS, theme, Zen shortcuts, …)
  • user services: kanata, tmux-save (shutdown snapshot), calendar sync, …
  • SSOT colors (if a wallpaper was available)
  • VS Code/Cursor shared settings + extensions (`vscode-cursor-sync.path`, idle timer)
  • Cursor AppImage hourly updater (`cursor-update.timer`; binary via `cursor-update --apply`)

NOT restored (by design — secrets / machine-local):
  • Browser profiles (Zen cookies/logins) — only shortcuts + user.js
  • SSH keys, GPG, gh auth tokens
  • Discord / Spotify / JetBrains / VS Code app data
  • OBS websocket password
  • Your wallpaper library (run wallpapers-fetch, or copy pictures/wallpapers yourself)

Manual follow-ups:
  1. wallpapers-fetch (or copy wallpapers → ~/pictures/wallpapers) && apply-wallpaper-theme <file>
  2. gh auth login   /  restore SSH keys
  3. Open Zen once via zen-browser (syncs shortcuts + Vimium CSS)
  4. Re-login so the input / i2c / video groups apply (kanata, ddcutil)
  5. New keyboards: add their /dev/input/by-id/*-event-kbd to kanata.kbd linux-dev
     and their names to KANATA_OWNED in hid-kbd-swallow.py
============================================================
EOF
