#!/usr/bin/env bash
# Restore packages from lists in this directory.
#
# Usage:
#   ./packages/install.sh [MODE] [--boot] [--no-hw]
#     (no MODE)  full restore: repo.txt + aur.txt + required.txt + detected hw-*.txt
#     --rice     curated rice only: rice-repo.txt + rice-aur.txt + required.txt
#     --repo     official part of the full set only (no yay needed)
#     --aur      AUR part of aur.txt only
#     --boot     also install hw-boot.txt (kernel, GRUB, plymouth) — opt-in
#     --no-hw    skip GPU/CPU autodetection of hw-*.txt
#   HW="nvidia intel-cpu" overrides autodetection (names of hw-<name>.txt).
#
# Names that exist neither in the sync DBs nor in the AUR are warned about and
# skipped; a failed install falls back to per-package installs. Failures are
# summed up at the end (exit 1), the rest is still installed.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

mode=all
boot=0
hw=1
for arg in "$@"; do
  case "$arg" in
    all|"") mode=all ;;
    --rice|rice) mode=rice ;;
    --repo|repo) mode=repo ;;
    --aur|aur) mode=aur ;;
    --boot) boot=1 ;;
    --no-hw) hw=0 ;;
    -h|--help|help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

warn() { printf 'warn: %s\n' "$*" >&2; }

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Print package names from list files: no comments, no blanks, unique.
read_lists() {
  local f
  for f in "$@"; do
    [[ -f "$f" ]] || { warn "missing list $f"; continue; }
    sed -e 's/#.*//' -e 's/[[:space:]]//g' "$f"
  done | grep -v '^$' | sort -u
}

# hw-*.txt names for this machine: GPU vendors from PCI class 0x03xx, CPU vendor.
detect_hw() {
  local dev class vendor
  for dev in /sys/bus/pci/devices/*; do
    class="$(cat "$dev/class" 2>/dev/null || true)"
    [[ "$class" == 0x03* ]] || continue
    vendor="$(cat "$dev/vendor" 2>/dev/null || true)"
    case "$vendor" in
      0x10de) echo nvidia ;;
      0x8086) echo intel-gpu ;;
      0x1002) echo amd-gpu ;;
    esac
  done
  case "$(grep -m1 '^vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')" in
    GenuineIntel) echo intel-cpu ;;
    AuthenticAMD) echo amd-cpu ;;
  esac
}

lists=()
case "$mode" in
  all|repo) lists=("$DIR/repo.txt" "$DIR/aur.txt" "$DIR/required.txt") ;;
  rice) lists=("$DIR/rice-repo.txt" "$DIR/rice-aur.txt" "$DIR/required.txt") ;;
  aur) lists=("$DIR/aur.txt") ;;
esac

if [[ "$mode" == all || "$mode" == repo ]]; then
  hw_names=()
  if [[ -n "${HW:-}" ]]; then
    read -r -a hw_names <<<"$HW"
  elif [[ "$hw" -eq 1 ]]; then
    mapfile -t hw_names < <(detect_hw | sort -u)
  fi
  [[ "$boot" -eq 1 ]] && hw_names+=(boot)
  for n in "${hw_names[@]}"; do
    echo "==> Hardware list: hw-$n.txt"
    lists+=("$DIR/hw-$n.txt")
  done
fi

mapfile -t wanted < <(read_lists "${lists[@]}")
[[ "${#wanted[@]}" -gt 0 ]] || { echo "Nothing to install."; exit 0; }

# --- classify: official (package or group) / AUR / missing -------------------
declare -A in_sync=()
while read -r n; do in_sync["$n"]=1; done < <(pacman -Slq 2>/dev/null; pacman -Sg 2>/dev/null | awk '{print $1}')

repo_pkgs=()
aur_candidates=()
for n in "${wanted[@]}"; do
  if [[ -n "${in_sync[$n]:-}" ]]; then repo_pkgs+=("$n"); else aur_candidates+=("$n"); fi
done

aur_pkgs=()
missing=()
if [[ "${#aur_candidates[@]}" -gt 0 ]]; then
  # One batched AUR RPC request for every non-repo name.
  query=""
  for n in "${aur_candidates[@]}"; do query+="arg[]=$n&"; done
  if resp="$(curl -fsS --max-time 30 "https://aur.archlinux.org/rpc/v5/info?${query%&}")"; then
    declare -A in_aur=()
    while read -r n; do in_aur["$n"]=1; done \
      < <(grep -o '"Name":"[^"]*"' <<<"$resp" | cut -d'"' -f4)
    for n in "${aur_candidates[@]}"; do
      if [[ -n "${in_aur[$n]:-}" ]]; then aur_pkgs+=("$n"); else missing+=("$n"); fi
    done
  else
    warn "AUR RPC unreachable; passing all non-repo names to yay unchecked"
    aur_pkgs=("${aur_candidates[@]}")
  fi
fi

for n in "${missing[@]}"; do
  warn "'$n' is in neither the sync DBs nor the AUR — skipped (drop it from the list)"
done

failed=()

# Each installer tries one transaction first; if that fails it retries one
# package at a time and collects the ones that still fail into $failed.
install_repo() {
  [[ "$#" -gt 0 ]] || return 0
  echo "==> Official packages ($# names)"
  as_root pacman -S --needed --noconfirm "$@" && return 0
  warn "batch pacman install failed; retrying per package"
  local p
  for p in "$@"; do
    as_root pacman -S --needed --noconfirm "$p" || failed+=("$p")
  done
}

YAY_OPTS=(--needed --noconfirm --sudoloop --answerclean None --answerdiff None --removemake)
install_aur() {
  [[ "$#" -gt 0 ]] || return 0
  if ! command -v yay >/dev/null 2>&1; then
    warn "yay not found — skipping $# AUR packages (https://github.com/Jguer/yay)"
    failed+=("$@")
    return 0
  fi
  echo "==> AUR packages ($# names)"
  yay -S "${YAY_OPTS[@]}" "$@" && return 0
  warn "batch yay install failed; retrying per package"
  local p
  for p in "$@"; do
    yay -S "${YAY_OPTS[@]}" "$p" || failed+=("$p")
  done
}

if [[ "$mode" != aur ]]; then install_repo "${repo_pkgs[@]}"; fi
if [[ "$mode" != repo ]]; then install_aur "${aur_pkgs[@]}"; fi

echo
if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "Skipped (no such package): ${missing[*]}"
fi
if [[ "${#failed[@]}" -gt 0 ]]; then
  echo "FAILED to install: ${failed[*]}" >&2
fi

echo
echo "Next:"
echo "  1. cd ~/dotfiles && ./restow.sh"
echo "  2. ~/.local/bin/kanata-setup.sh   # uinput + input group, then re-login"
echo "  3. apply-wallpaper-theme /path/to/wallpaper.jpg   # rebuild SSOT colors"
echo "  4. exec fish"

[[ "${#failed[@]}" -eq 0 ]]
