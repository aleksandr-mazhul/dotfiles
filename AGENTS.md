# AGENTS.md

## Cursor Cloud specific instructions

This repo is a **personal Linux dotfiles / desktop-ricing** collection (Hyprland + Wayland,
theming, panels, terminal, shell). It is **not** a software product: there is no package
manager manifest, no build system, no tests, and no network services/ports. Each top-level
directory (`hypr`, `waybar`, `vibepanel`, `kitty`, `fish`, `wofi`, `fastfetch`, `matugen`,
`gtk`, `bin`, etc.) is a **GNU Stow package** whose contents mirror their real destination
under `$HOME` (e.g. `hypr/.config/hypr/` -> `~/.config/hypr/`).

### Deploy the dotfiles (the repo's core "run" step)
- `./restow.sh` symlinks every package into `$HOME` via `stow --adopt`. This is the primary
  action this repo performs. `stow` is the only dependency and is installed by the update script.
- Caveat: `restow.sh` uses `stow --adopt`, which **moves pre-existing real files from `$HOME`
  into the repo** (adopting live config content) before symlinking. On a fresh cloud VM this can
  modify tracked files under `gtk/` (the VM ships a live `~/.config/gtk-3.0/`). After running it,
  check `git status` and `git checkout -- <path>` to discard any unintended adopted changes so the
  working tree stays clean.
- A `WARN .config/gtk-3.0 has non-symlink files` line for `gtk.dark.css` is expected/benign: that
  file exists in the VM's live `~/.config/gtk-3.0/` and is not part of this repo.

### Lint / validate (no linter is configured in the repo)
- Shell scripts: `bash -n <file>` (all `*.sh` currently pass).
- TOML: validate with Python `tomllib` (`matugen` and `vibepanel` configs).
- JSON configs are actually **JSONC** (comments + trailing commas) consumed by waybar/fastfetch's
  own parsers, so strict `jq`/`json.loads` will report false errors on them — do not treat that as
  a real failure.

### Cannot run headless
The actual desktop (Hyprland Wayland compositor, waybar/vibepanel, quickshell QML overlays, swww,
SDDM) requires a **real Wayland session with a GPU** and the corresponding system binaries, which
are not available in a headless cloud VM. End-to-end validation here is limited to deploying the
configs with Stow and syntax-checking them. `sddm/install.sh` is system-level (needs `sudo`/`pkexec`)
and is intentionally not part of `restow.sh`.
