# Restore scope — what bootstrap covers

## One command

```bash
git clone git@github.com:aleksandr-mazhul/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh          # everything
# ./bootstrap.sh --rice # smaller package set
```

Optional wallpaper override:

```bash
BOOTSTRAP_WALLPAPER=~/Pictures/Wallpapers/nature/foo.jpg ./bootstrap.sh
```

## What is in git (restorable)

| Area | Location |
| --- | --- |
| Package inventory | `packages/repo.txt`, `packages/aur.txt`, curated `rice-*.txt` |
| Hyprland / scripts | `hypr/` |
| Kitty, Fish, Tmux, Starship | `kitty/`, `fish/`, `tmux/`, `starship/` |
| Kanata + systemd unit | `kanata/` |
| Theme SSOT templates + pipeline | `theme/`, `bin/.local/bin/theme-*` |
| Quickshell rice | `quickshell/` |
| nvim LazyVim rice | `nvim/` |
| Zen shortcuts + user.js + Vimium mirror | `zen/` (+ `zen-browser` launcher) |
| OBS scenes/profiles (no websocket password) | `obs/` |
| GTK / wofi / yazi / waypaper / … | matching packages |
| Global git config | `git/.gitconfig` |
| SDDM theme assets | `sddm/` (applied via `sddm/install.sh`) |

SSOT-generated files (`~/.config/cava/themes/ssot`, `btop` theme, `glow/ssot.json`,
`peaclock`, `bottom.toml`, `lazygit`, `bat`, Vimium CSS, …) are **rebuilt** by
`theme-render` / `apply-wallpaper-theme` — they do not need separate copies in git.

## What is intentionally NOT in git

| Data | Why |
| --- | --- |
| Zen/Firefox full profile | cookies, logins, history |
| `gh` hosts.yml / tokens | secrets |
| SSH / GPG private keys | secrets |
| Discord, Spotify, JetBrains, VS Code caches | huge + machine-local |
| OBS websocket password | secret (gitignored) |
| Wallpaper image library | large binaries — copy separately |
| `chromium-ffmpeg/` nested git | ignored; rebuild if needed |

After bootstrap, copy secrets/media yourself, then `exec fish`.
