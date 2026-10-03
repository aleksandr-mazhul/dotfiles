# Dotfiles — Hyprland rice (Arch Linux)

**English** · [Русский](README.ru.md)

Personal environment on **Arch + Hyprland**: Mac-like input (Kanata), a dynamic palette derived from the wallpaper (SSOT), Quickshell UI, Kitty/Fish/Tmux, Zen Browser, and a full package inventory for restoring from scratch.

Managed through **[GNU Stow](https://www.gnu.org/software/stow/)**. Secrets are not included in the repository.

One command on a fresh Arch user: `./bootstrap.sh`. That installs the package lists, links these configs into `$HOME`, and enables the greeter, sound, and network. `--rice` is a smaller package set for a machine that already has a session — it does not install SDDM, PipeWire, or NetworkManager.

What you get:

- Hyprland, with Kanata home-row mods so the keyboard feels like a Mac
- Quickshell bar, launcher, clipboard, wallpaper picker, and notifications
- A palette taken from the wallpaper and rendered through the rest of the desktop
- Kitty, Fish, and tmux — Zellij is one variable away (`MUX=zellij`)
- Zen Browser shortcuts only; the profile stays on the machine

Screenshots of the desktop, the bar, and the launcher are not in the tree yet. When you have a clean frame, put `desktop.png`, `bar.png`, and `launcher.png` in `docs/screenshots/` and they belong at the top of this page.

| Document | Why open it |
| --- | --- |
| **[KEYBINDS.md](KEYBINDS.md)** | All hotkeys: Hyprland, kitty, nvim, kanata |
| **[RESTORE.md](RESTORE.md)** | What bootstrap covers and what it doesn't |
| **[AGENTS.md](AGENTS.md)** | Checklist for AI agents when adding new apps |
| **[packages/](packages/)** | pacman / AUR package lists |
| **[theme/…/README.md](theme/.config/theme/README.md)** | Color pipeline (SSOT) |

---

## Quick start

```bash
git clone https://github.com/aleksandr-mazhul/dotfiles.git ~/dotfiles   # HTTPS: SSH keys aren't restored yet
cd ~/dotfiles
./bootstrap.sh
```

| Command | What it does |
| --- | --- |
| `./bootstrap.sh` | Packages (`repo` + `aur` + `required` + `hw-*` by hardware) → restow → groups → `/etc` → tpm and zellij plugins → user services → fish → theme → SDDM (enabled) |
| `./bootstrap.sh --rice` | Curated packages only (`rice-*.txt` + `required`). No display manager, PipeWire, or NetworkManager |
| `./bootstrap.sh --configs` | Configs / services / theme only (packages already installed) |
| `./restow.sh` | Stow symlinks into `$HOME`; conflicting files → `~/.dotfiles-backup/<ts>/` |
| `./restow.sh --check` / `--adopt` | Only check / adopt live files into the repo |

After bootstrap — **log out and back in** (`input`, `i2c`, `video` groups for kanata and ddcutil). New keyboards: add to `kanata.kbd` (`linux-dev`) and `hid-kbd-swallow.py` — see [RESTORE.md](RESTORE.md).

Wallpaper during bootstrap (optional):

```bash
BOOTSTRAP_WALLPAPER=~/pictures/wallpapers/old/nature-01.jpg ./bootstrap.sh
```

After install: copy wallpapers and keys, `gh auth login`, open Zen once via `zen-browser`, `exec fish`.

---

## Theme architecture (SSOT)

```text
Wallpaper
   │
   ▼
theme-extract → theme-match → theme-build → palette.toml (SSOT)
                                              │
                                         theme-render
                                              │
    ┌───────────┬──────────┬─────────┬────────┼────────┬──────────┐
    ▼           ▼          ▼         ▼        ▼        ▼          ▼
  Kitty      Hyprland   Quickshell  GTK    nvim     tmux/starship  …
  Zen/Vimium  lock      wofi/yazi   bat    btop     cava/glow/…
```

Wallpapers and transition animations:

```bash
wallpapers-fetch                 # download the library (~500 wallpapers, dharmx/walls) to ~/pictures/wallpapers
wallpaper-transition list        # ~40 presets: swipe / diag / wave / explode / implode / tear / slash
wallpaper-transition set random  # random (default) or a preset name; in the launcher: Ctrl+T
```

After changing the wallpaper:

```bash
apply-wallpaper-theme ~/pictures/wallpapers/….jpg
exec fish   # refresh fish wrappers (cbonsai, pipes, gum, …)
```

Just re-render consumers from the current `palette.toml`: `theme-render`.

---

## Repository map

Each directory below is a **Stow package**, except where the row says otherwise:
`<pkg>/.config/...` → `~/.config/...`, `<pkg>/.local/...` → `~/.local/...`.

### Desktop core

| Package | Purpose |
| --- | --- |
| [`hypr/`](hypr/) | Hyprland **Lua**: windows, binds, rules, monitors, hyprlock, scripts (screenshot, OCR, clipboard, Nautilus Mac binds, Zoom tabs) |
| [`kanata/`](kanata/) | Home-row mods + remaps; user systemd unit |
| [`quickshell/`](quickshell/) | Rice UI: bar, launcher, clipboard, wallpaper, VPN, calendar, notifications, design system (`ds/`), vim-engine |
| [`sddm/`](sddm/) | Adaptive login theme. **Not Stow** — `sddm/install.sh` copies it to `/usr` and enables `sddm.service` |
| [`waybar/`](waybar/) | Fallback bar config (the main bar is Quickshell) |
| [`vibepanel/`](vibepanel/) | Old panel config, kept beside Quickshell |

### Terminal and shell

| Package | Purpose |
| --- | --- |
| [`kitty/`](kitty/) | Main terminal; SSOT colors/tabs; Mac-like clipboard (`Ctrl+C/V`, `Super+C` = interrupt) |
| [`fish/`](fish/) | Login shell, fzf/rice theme snippets |
| [`tmux/`](tmux/) | Resurrect + continuum, status from SSOT |
| [`zellij/`](zellij/) | Optional mux beside tmux. tmux stays the default; `MUX=zellij` switches the next kitty window |
| [`starship/`](starship/) | Prompt from the same palette |
| [`nvim/`](nvim/) | LazyVim + `palette.lua` / SSOT colors |
| [`yazi/`](yazi/) | File-manager TUI + theme + plugins |
| [`fastfetch/`](fastfetch/) | Fetch on fish startup |

### Theme and appearance

| Package | Purpose |
| --- | --- |
| [`theme/`](theme/) | `harmonies.toml`, templates, SSOT docs |
| [`bin/`](bin/) | `theme-*`, `apply-wallpaper-theme`, `zen-browser`, helpers |
| [`matugen/`](matugen/) | Material/wallpaper color helpers (alongside SSOT) |
| [`gtk/`](gtk/) | GTK 3/4 CSS (theme consumers) |
| [`wofi/`](wofi/) | Fallback launcher styles |
| [`waypaper/`](waypaper/) | Wallpaper picker → theme pipeline |
| [`nwg-look/`](nwg-look/) | GTK settings / look |
| [`xsettingsd/`](xsettingsd/) | XSettings for GTK/Qt under the Wayland stack |
| [`x11/`](x11/) | `.Xresources` and small X11 glue |

### Applications and utilities

| Package | Purpose |
| --- | --- |
| [`zen/`](zen/) | Shortcuts, `user.js`, Vimium mirror (full profile **not** in git) |
| [`git/`](git/) | Global `.gitconfig` (delta, aliases, `merge.ff=false`) |
| [`obs/`](obs/) | Recording scenes/profiles (without the websocket password) |
| [`herdr/`](herdr/) | Additional theming consumer |
| [`entropy/`](entropy/) | Entropy GUI settings (autostart off — hangs on Hypr; use `eh-layout-sync`) |
| [`misc/`](misc/) | mimeapps (a real file, not a symlink — GIO cannot save next to one), gromit-mpx, ergohaven notes |
| [`voxtype/`](voxtype/) | Dictation |
| [`vscode/`](vscode/) | VS Code / Cursor shared settings (`vscode-cursor-sync`). The Cursor AppImage is not in git |

### Documentation and meta

| Path | Purpose |
| --- | --- |
| [`KEYBINDS.md`](KEYBINDS.md) | Hotkey cheatsheet |
| [`docs/`](docs/) | Extra notes. `docs/zellij-migration/` is a historical audit |
| [`packages/`](packages/) | `repo.txt` / `aur.txt` / `rice-*.txt` / `ignore.txt`, install and export |
| [`system/`](system/) | **Not Stow.** `/etc` udev rules, zram, docker socket, NetworkManager, Bluetooth (`system/install.sh`) |
| [`AGENTS.md`](AGENTS.md) | Maintainer checklist for adding an app. Not part of the desktop |
| `bootstrap.sh` / `restow.sh` | Restore and Stow |
| [`tests/`](tests/) | Shell checks for zellij, wallpaper, vpn, fish |

Not in Stow: `chromium-ffmpeg/` (ignored, a separate nested tree).

---

## Key ideas

### Modifiers

- **`Alt`** (`mainMod`) — windows and workspaces (skhd-style, Mac-oriented)
- **`Super`** (`secondMod`) — system, bar, utilities, lock
- In applications **Ctrl ≈ Cmd** (close tab, quit app, Finder-like Nautilus)
- Kanata: home-row mods; `Super+Shift+[ ]` → `Ctrl+PgUp/Dn` (tabs / tmux/zellij)

Full list: **[KEYBINDS.md](KEYBINDS.md)**. Quick anchors:

| Keys | Action |
| --- | --- |
| `Super+B` | Hide the bar (autohide) / pin it back; hover the top edge to peek |
| `Alt+O` | Launcher |
| `Super+Q` | Clipboard history |
| `Super+W` | Wallpaper picker |
| `Ctrl+C` / `Ctrl+V` | Copy / paste in kitty |
| `Super+C` | Interrupt (SIGINT) in kitty |

### Quickshell rice

Bar (islands), launcher, clipboard, wallpaper, VPN panel, calendar, notifications, on-screen draw hooks. Colors come from `Colors.qml` (SSOT render). Design-system primitives live in `quickshell/.../rice/ds/`.

### Theme SSOT

Single source: `~/.config/theme/palette.toml`.
Rendered into Hypr, lock, Kitty, GTK3/4, Quickshell, Wofi, Starship, Tmux, Zellij, Yazi, fzf, bat, lazygit, nvim, Herdr, Vimium, btop, cava, peaclock, glow, bottom, and fish wrappers for rice utilities.

### Zen Browser

Only shortcuts / `user.js` / Vimium mirror are in git. The `zen-browser` launcher syncs them into the profile. Cookies and logins stay local.

### Git

`merge.ff = false` and `pull.ff = false` — merges always produce a merge commit (no fast-forward). Diff/pager via **delta**.

---

## Packages and new applications

| File | Contents |
| --- | --- |
| `packages/repo.txt` | Official (pacman) |
| `packages/aur.txt` | AUR (without `*-debug`) |
| `packages/rice-*.txt` | Curated rice minimum |
| `packages/required.txt` | Runtime dependencies of the repo's scripts (always installed, except with `--aur`) |
| `packages/hw-*.txt` | Drivers/microcode by GPU/CPU vendor (autodetected); `hw-boot.txt` — only with `--boot` |
| `packages/install.sh` | Installs the lists; skips nonexistent names, lists failures at the end |
| `packages/ignore.txt` | Installed on this machine, deliberately not restored |
| `packages/export.sh` | Update `repo.txt`/`aur.txt` from the current machine (skips `hw-*`, `required`, `ignore`) |

After installing something new:

```bash
./packages/export.sh
# or
dotfiles-register-app <pkg> [--aur] [--rice]
./restow.sh          # if a config was added to a Stow package
# if needed — a template under theme/ + mapping in theme-render
```

---

## Day-to-day

```bash
# Change the wallpaper and recolor the whole stack
apply-wallpaper-theme ~/pictures/wallpapers/….jpg

# Just re-render consumers from the current palette.toml
theme-render

# Only the Vimium CSS (better to close Zen first)
theme-vimium

# Relink symlinks after editing the repo
./restow.sh
```

Useful rice commands (after `exec fish`): `cava`, `btop`, `btm`, `peaclock`, `cbonsai -l`, `tty-clock`, `pipes.sh`, `glow README.md`.

---

## What isn't restored from git

| Data | Reason |
| --- | --- |
| Zen profile / browser passwords | secrets and PII |
| SSH / GPG / `gh` tokens | secrets |
| Discord, Spotify, JetBrains, VS Code data | heavy and machine-local |
| OBS websocket password | gitignored |
| Wallpaper library | `wallpapers-fetch` (or copy into `~/pictures/wallpapers`) |
| Cursor AppImage | `cursor-update --apply` after restore |
| vdirsyncer / khal tokens and account names | machine-local; see `RESTORE.md` |
| `chromium-ffmpeg/` | nested / ignored |

---

## Requirements

- Arch Linux (or a pacman-compatible distro)
- Network + `sudo` (packages and SDDM)
- A real terminal for password prompts (`yay` / `sudo`)
- For Kanata: the `input` group, then re-login

---

## License / use

Personal rice. See [LICENSE](LICENSE). Fork it and adapt it; there is no warranty.

Most paths are tied to `$HOME` / `~` / `Path.home()`. When migrating, still check:

- `ZEN_PROFILE` — the Zen profile folder id is unique per machine
- `gtk` bookmarks and OBS `*.ini` — apps write absolute `file://` paths/paths themselves
- `restow.sh` target (`$HOME`) and the lists under `packages/`
