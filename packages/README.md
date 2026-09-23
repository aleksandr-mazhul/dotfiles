# Package lists — restore apps after a reinstall

**Full machine restore:** `./bootstrap.sh` (see [`../RESTORE.md`](../RESTORE.md)).

These files are the inventory of what this machine runs. Refresh after big
installs with:

```bash
./packages/export.sh
git add packages/repo.txt packages/aur.txt && git commit -m "chore: refresh package lists"
```

## Files

| File | What |
| --- | --- |
| `repo.txt` | Explicitly installed **official** packages (`pacman -Qqen`), minus hw/required |
| `aur.txt` | Explicitly installed **foreign/AUR** packages (`pacman -Qqem`, no `*-debug`) |
| `required.txt` | Runtime deps of the repo's scripts (pillow, ripgrep, wl-clipboard, jq, socat, matugen, uv, khal, waypaper, …) — official or AUR, hand-kept |
| `rice-repo.txt` | Curated Hyprland rice + CLI tools (official) |
| `rice-aur.txt` | Curated AUR rice (Zen, kanata, cbonsai, …) |
| `hw-nvidia.txt`, `hw-intel-gpu.txt`, `hw-amd-gpu.txt` | GPU drivers — auto-picked from PCI class `03xx` vendor |
| `hw-intel-cpu.txt`, `hw-amd-cpu.txt` | Microcode — auto-picked from `/proc/cpuinfo` |
| `hw-boot.txt` | Kernel, headers, GRUB, efibootmgr, plymouth — **opt-in** (`--boot`) |

`export.sh` never writes names that are in `hw-*.txt` or `required.txt`; keep
those, and the `rice-*` lists, by hand.

## Restore

```bash
# From repo root — preferred
./bootstrap.sh

# Or packages only:
./packages/install.sh                  # full: repo + aur + required + detected hw
./packages/install.sh --rice           # curated + required (no hw lists)
./packages/install.sh --repo           # official part only (no yay)
./packages/install.sh --aur            # aur.txt only
./packages/install.sh --boot           # full + hw-boot.txt
./packages/install.sh --no-hw          # full without hw lists
HW="amd-gpu amd-cpu" ./packages/install.sh   # override detection
```

Every name is checked first (sync DBs via one `pacman -Slq`, AUR via one
batched RPC call); names found nowhere are warned about and skipped. pacman and
yay each try one transaction and fall back to one package at a time; failures
are listed at the end and the script exits 1 after installing everything else.

No listed package needs `[multilib]`.

Then secrets/media (SSH, wallpapers, browser logins) are manual — see [`../RESTORE.md`](../RESTORE.md).
