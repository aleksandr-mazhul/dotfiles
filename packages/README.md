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
| `repo.txt` | All explicitly installed **official** packages (`pacman -Qqe` minus AUR) |
| `aur.txt` | All **AUR** packages (debug pkgs stripped) |
| `rice-repo.txt` | Curated Hyprland rice + CLI tools (official) |
| `rice-aur.txt` | Curated AUR rice (Zen, kanata, cbonsai, …) |

## Restore

```bash
# From repo root — preferred
./bootstrap.sh

# Or packages only:
./packages/install.sh          # full
./packages/install.sh --rice   # curated
```

Then secrets/media (SSH, wallpapers, browser logins) are manual — see [`../RESTORE.md`](../RESTORE.md).
