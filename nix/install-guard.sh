#!/bin/sh
# Proves install-machine refuses aliases of the root disk and the live ISO
# disk. findmnt and lsblk are fakes. Nothing is partitioned.
set -eu

install=${1:?install-machine.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat > "$tmp/bin/findmnt" << 'EOF'
#!/bin/sh
target=""
types=""
prev=""
for a in "$@"; do
  case "$prev" in
    --target) target=$a ;;
    -t) types=$a ;;
  esac
  prev=$a
done
if [ "$types" = iso9660 ]; then
  printf '%s\n' /dev/disk/by-label/STRANGER
  exit 0
fi
case "$target" in
  /) printf '%s\n' /dev/nvme0n1p2 ;;
  /iso) printf '%s\n' /dev/disk/by-label/STRANGER ;;
  /nix/.ro-store) printf '%s\n' /dev/loop0 ;;
  *) exit 1 ;;
esac
EOF

cat > "$tmp/bin/lsblk" << 'EOF'
#!/bin/sh
col=""
dev=""
prev=""
for a in "$@"; do
  case "$prev" in
    -o) col=$a ;;
  esac
  case "$a" in
    -*) ;;
    *) dev=$a ;;
  esac
  prev=$a
done
# A case pattern treats "|" as alternation, so the key uses a space.
case "$dev $col" in
  "/dev/nvme0n1p2 PKNAME") printf '%s\n' nvme0n1 ;;
  "/dev/nvme0n1p2 NAME") printf '%s\n' nvme0n1p2 ;;
  "/dev/nvme0n1 NAME") printf '%s\n' nvme0n1 ;;
  "/dev/disk/by-id/nvme-KINGSTON_SNV2S500G_50026B76866AEA46 NAME") printf '%s\n' nvme0n1 ;;
  "/dev/disk/by-path/pci-0000:01:00.0-nvme-1 NAME") printf '%s\n' nvme0n1 ;;
  "/dev/disk/by-uuid/root-part PKNAME") printf '%s\n' nvme0n1 ;;
  "/dev/disk/by-uuid/root-part NAME") printf '%s\n' nvme0n1p2 ;;
  "/dev/disk/by-label/STRANGER PKNAME") printf '%s\n' sdb ;;
  "/dev/disk/by-label/STRANGER NAME") printf '%s\n' sdb1 ;;
  "/dev/sdb NAME") printf '%s\n' sdb ;;
  "/dev/sdb1 PKNAME") printf '%s\n' sdb ;;
  "/dev/sdb1 NAME") printf '%s\n' sdb1 ;;
  "/dev/disk/by-id/usb-Live_Stick NAME") printf '%s\n' sdb ;;
  "/dev/loop0 NAME") printf '%s\n' loop0 ;;
  "/dev/sda NAME") printf '%s\n' sda ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/findmnt" "$tmp/bin/lsblk"

export PATH="$tmp/bin:$PATH"
export FLAKE_ROOT=/tmp/flake-root

expect_refuse() {
  disk=$1
  label=$2
  if "$install" --dry-run "$disk" >"$tmp/out" 2>"$tmp/err"; then
    echo "expected refusal for $label ($disk)" >&2
    cat "$tmp/err" >&2
    exit 1
  fi
  if ! grep -q "Refusing: $disk is the disk the running system is using" "$tmp/err"; then
    echo "refusal for $label did not name the running disk" >&2
    cat "$tmp/err" >&2
    exit 1
  fi
}

expect_refuse /dev/nvme0n1 "kernel name of the root disk"
expect_refuse /dev/nvme0n1p2 "root partition"
expect_refuse /dev/disk/by-id/nvme-KINGSTON_SNV2S500G_50026B76866AEA46 "by-id alias of the root disk"
expect_refuse /dev/disk/by-path/pci-0000:01:00.0-nvme-1 "by-path alias of the root disk"
expect_refuse /dev/disk/by-uuid/root-part "by-uuid alias of the root partition"
expect_refuse /dev/sdb "kernel name of the live ISO disk"
expect_refuse /dev/sdb1 "live ISO partition"
expect_refuse /dev/disk/by-id/usb-Live_Stick "by-id alias of the live ISO"
expect_refuse /dev/disk/by-label/STRANGER "by-label of the live ISO"
expect_refuse /dev/loop0 "squashfs the live store is running from"

if ! "$install" --dry-run /dev/sda >"$tmp/out" 2>"$tmp/err"; then
  echo "an unrelated disk should dry-run" >&2
  cat "$tmp/err" >&2
  exit 1
fi
if ! grep -q 'disko-install --disk main /dev/sda' "$tmp/out"; then
  echo "dry-run of an unrelated disk did not print disko-install" >&2
  cat "$tmp/out" "$tmp/err" >&2
  exit 1
fi

echo "install-guard: root aliases and the live ISO disk are refused"
