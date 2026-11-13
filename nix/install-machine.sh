#!/bin/sh
# Install this flake onto one whole disk. The disk is never implied: pass it.
# Refuses the disk that currently holds /. Does not partition anything in
# --dry-run. Example: install-machine --dry-run /dev/nvme0n1
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

if command -v findmnt >/dev/null 2>&1 && command -v lsblk >/dev/null 2>&1; then
  root_src=$(findmnt -nr -o SOURCE / || true)
  if [ -n "$root_src" ]; then
    pk=$(lsblk -no PKNAME "$root_src" 2>/dev/null || true)
    if [ -n "$pk" ] && [ "/dev/$pk" = "$disk" ]; then
      echo "Refusing: $disk holds the running root filesystem ($root_src)." >&2
      exit 1
    fi
    if [ "$root_src" = "$disk" ]; then
      echo "Refusing: $disk is the running root filesystem." >&2
      exit 1
    fi
  fi
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
