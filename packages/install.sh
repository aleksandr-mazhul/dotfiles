#!/usr/bin/env bash
# Restore packages from lists in this directory.
#
# Usage:
#   ./packages/install.sh           # full system restore (repo.txt + aur.txt)
#   ./packages/install.sh --rice    # curated rice only (rice-repo.txt + rice-aur.txt)
#   ./packages/install.sh --repo    # official packages only
#   ./packages/install.sh --aur     # AUR only (needs yay)
#
# After packages: clone/pull this repo, then ./restow.sh and apply a wallpaper theme.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
mode="${1:-all}"

need_root_pacman() {
  if [[ "$(id -u)" -eq 0 ]]; then
    pacman "$@"
  else
    sudo pacman "$@"
  fi
}

filter_pkgs() {
  # drop comments / blanks
  grep -vE '^\s*(#|$)' "$1"
}

install_repo() {
  local list="$1"
  [[ -f "$list" ]] || { echo "missing $list" >&2; exit 1; }
  echo "==> Official packages from $(basename "$list")"
  # shellcheck disable=SC2046
  need_root_pacman -S --needed --noconfirm $(filter_pkgs "$list")
}

install_aur() {
  local list="$1"
  [[ -f "$list" ]] || { echo "missing $list" >&2; exit 1; }
  if ! command -v yay >/dev/null 2>&1; then
    echo "yay not found. Install yay first, then re-run with --aur / --rice / default." >&2
    echo "  https://github.com/Jguer/yay" >&2
    exit 1
  fi
  echo "==> AUR packages from $(basename "$list")"
  # Interactive password OK — run in a real terminal
  # shellcheck disable=SC2046
  yay -S --needed $(filter_pkgs "$list")
}

case "$mode" in
  all|"")
    install_repo "$DIR/repo.txt"
    install_aur "$DIR/aur.txt"
    ;;
  --rice|rice)
    install_repo "$DIR/rice-repo.txt"
    install_aur "$DIR/rice-aur.txt"
    ;;
  --repo|repo)
    install_repo "$DIR/repo.txt"
    ;;
  --aur|aur)
    install_aur "$DIR/aur.txt"
    ;;
  -h|--help|help)
    sed -n '2,14p' "$0"
    exit 0
    ;;
  *)
    echo "Unknown mode: $mode (try --help)" >&2
    exit 2
    ;;
esac

echo
echo "Done. Next:"
echo "  1. cd ~/dotfiles && ./restow.sh"
echo "  2. systemctl --user enable --now kanata.service   # if using kanata"
echo "  3. apply-wallpaper-theme /path/to/wallpaper.jpg   # rebuild SSOT colors"
echo "  4. exec fish"
