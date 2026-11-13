#!/usr/bin/env bash
# Snapshot of everything installed/enabled on this machine, written as plain
# text under migration/inventory/. Contains no secrets, so it is safe to commit.
# Re-run before the cut-over; the NixOS parity check diffs against these files.
set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$root/inventory"
mkdir -p "$out"

have() { command -v "$1" >/dev/null 2>&1; }
snap() { # snap <file> <command...>: write stdout, never fail the whole run
  local f="$out/$1"
  shift
  "$@" >"$f" 2>/dev/null || true
}

# --- packages -----------------------------------------------------------
snap pacman-native.txt pacman -Qqen
snap pacman-aur.txt pacman -Qqem
have flatpak && snap flatpak.txt flatpak list --app --columns=application,origin
have npm && snap npm-global.txt npm ls -g --depth=0 --parseable
have pipx && snap pipx.txt pipx list --short
have uv && snap uv-tools.txt uv tool list
have cargo && snap cargo.txt cargo install --list
have code && snap vscode-extensions.txt code --list-extensions
snap local-bin.txt find "$HOME/.local/bin" -maxdepth 1 -mindepth 1 -printf '%y %f\n'
snap go-bin.txt ls "$HOME/go/bin"
snap nvim-mason.txt ls "$HOME/.local/share/nvim/mason/bin"

# --- services and system state -----------------------------------------
snap services-system.txt systemctl list-unit-files --state=enabled --no-legend
snap services-user.txt systemctl --user list-unit-files --state=enabled --no-legend
snap units-custom-etc.txt find /etc/systemd/system -maxdepth 1 -type f -printf '%f\n'
snap groups.txt id
snap hostinfo.txt bash -c 'uname -r; hostnamectl --static; timedatectl show -p Timezone; localectl status'
snap grub-default.txt grep -v '^#' /etc/default/grub
snap fstab.txt grep -v '^#' /etc/fstab
snap cmdline.txt cat /proc/cmdline
snap lsmod.txt lsmod

# --- hardware -----------------------------------------------------------
snap lspci.txt lspci -nn
snap lsusb.txt lsusb
snap lsblk.txt lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL,MOUNTPOINTS
snap efibootmgr.txt efibootmgr

# --- docker / dconf -----------------------------------------------------
if have docker; then
  snap docker-images.txt docker images --format '{{.Repository}}:{{.Tag}}'
  snap docker-volumes.txt docker volume ls --format '{{.Name}}'
fi
have dconf && snap dconf.ini dconf dump /

# --- ~/.config coverage: which entries are NOT symlinked into this repo --
{
  for d in "$HOME"/.config/*; do
    name="${d##*/}"
    if [ -L "$d" ] && readlink -f "$d" | grep -q '/dotfiles/'; then
      echo "stowed  $name"
    elif [ -d "$d" ] && find "$d" -maxdepth 2 -type l -lname '*dotfiles*' 2>/dev/null | grep -q .; then
      echo "partial $name"
    else
      echo "loose   $name"
    fi
  done
} >"$out/config-coverage.txt"

# --- git repos under $HOME with uncommitted or unpushed work ------------
{
  find "$HOME" -maxdepth 5 -name .git -type d \
    -not -path '*/node_modules/*' -not -path '*/.cache/*' \
    -not -path '*/.local/share/*' -not -path '*/.config/*' 2>/dev/null |
    while read -r g; do
      r="$(dirname "$g")"
      dirty="$(git -C "$r" status --porcelain 2>/dev/null | wc -l)"
      ahead="$(git -C "$r" log --branches --not --remotes --oneline 2>/dev/null | wc -l)"
      remotes="$(git -C "$r" remote 2>/dev/null | wc -l)"
      echo "dirty=$dirty unpushed=$ahead remotes=$remotes ${r#"$HOME"/}"
    done | sort
} >"$out/git-repos.txt"

# --- plain-text defaults for tools that do not leave state elsewhere ----
snap mimeapps.list cat "$HOME/.config/mimeapps.list"

echo "inventory written to ${out#"$PWD"/} ($(find "$out" -type f | wc -l) files)"
