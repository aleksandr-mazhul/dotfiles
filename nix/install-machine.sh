#!/bin/sh
# Install this flake onto one whole disk. The disk is never implied: pass it.
# Refuses the disk that holds /, the live image at /iso, or any other disk
# the running system is booted from. by-id, by-path, by-uuid, and /dev/sdX
# are the same disk when lsblk says so. --dry-run only prints the command.
# Example: install-machine --dry-run /dev/nvme0n1
set -eu

dry=0
disk=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      exit 2
      ;;
    *)
      disk="$1"
      shift
      ;;
  esac
done

if [ -z "$disk" ]; then
  echo "Refusing to install: pass the target whole disk (for example /dev/nvme0n1)." >&2
  echo "This command never guesses a disk and never formats the disk that holds /." >&2
  exit 1
fi

case "$disk" in
  /dev/*) ;;
  *)
    echo "Disk must be a /dev path, got: $disk" >&2
    exit 1
    ;;
esac

# Kernel name of the whole disk behind a path (nvme0n1, sda). Empty if the
# path is not a block device lsblk can see. A partition and its by-id alias
# both resolve to the parent disk.
whole_disk() {
  dev=$1
  dev=${dev%%\[*}
  case "$dev" in
    LABEL=*) dev="/dev/disk/by-label/${dev#LABEL=}" ;;
    UUID=*) dev="/dev/disk/by-uuid/${dev#UUID=}" ;;
    PARTUUID=*) dev="/dev/disk/by-partuuid/${dev#PARTUUID=}" ;;
  esac
  case "$dev" in
    /dev/*) ;;
    *) return 0 ;;
  esac
  pk=$(lsblk -n -o PKNAME -- "$dev" 2>/dev/null || true)
  set -- $pk
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1"
    return 0
  fi
  name=$(lsblk -n -o NAME -- "$dev" 2>/dev/null || true)
  set -- $name
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1"
  fi
}

if command -v findmnt >/dev/null 2>&1 && command -v lsblk >/dev/null 2>&1; then
  target_disk=$(whole_disk "$disk")
  sources=$(
    findmnt -nr -o SOURCE --target / 2>/dev/null || true
    findmnt -nr -o SOURCE --target /iso 2>/dev/null || true
    findmnt -nr -o SOURCE --target /nix/.ro-store 2>/dev/null || true
    findmnt -nr -o SOURCE -t iso9660 2>/dev/null || true
  )
  for src in $sources; do
    src_disk=$(whole_disk "$src")
    if [ -n "$target_disk" ] && [ "$target_disk" = "$src_disk" ]; then
      echo "Refusing: $disk is the disk the running system is using ($src -> $src_disk)." >&2
      exit 1
    fi
  done
fi

root="${FLAKE_ROOT:-}"
if [ -z "$root" ]; then
  echo "FLAKE_ROOT is not set." >&2
  exit 1
fi

echo "Install flake $root#stranger onto $disk (disko name: main)."
if [ "$dry" -eq 1 ]; then
  echo "disko-install --disk main $disk --flake $root#stranger"
  exit 0
fi

if [ ! -b "$disk" ]; then
  echo "Not a block device: $disk" >&2
  exit 1
fi

exec disko-install --disk main "$disk" --flake "$root#stranger"
