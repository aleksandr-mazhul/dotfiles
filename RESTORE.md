# Restore scope — what bootstrap covers

## One command

```bash
git clone git@github.com:aleksandr-mazhul/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh          # everything
# ./bootstrap.sh --rice # smaller package set
```

Wallpaper library (not in git): `wallpapers-fetch`. Optional wallpaper override:

```bash
BOOTSTRAP_WALLPAPER=~/pictures/wallpapers/old/nature-01.jpg ./bootstrap.sh
```

## What is in git (restorable)

| Area | Location |
| --- | --- |
| Package inventory | `packages/repo.txt`, `packages/aur.txt`, curated `rice-*.txt` |
| Hyprland / scripts | `hypr/` |
| Kitty, Fish, Tmux, Starship | `kitty/`, `fish/`, `tmux/`, `starship/` |
| Kanata + systemd unit | `kanata/` |
| Theme SSOT templates + pipeline | `theme/`, `bin/.local/bin/theme-*` |
| VS Code + Cursor (shared settings, keybindings, extension lists) | `vscode/` → `vscode-cursor-sync` + `vscode-cursor-sync.path` + idle timer |
| Cursor AppImage updater | `bin/` → `cursor` wrapper, `cursor-update` + user timer `cursor-update.timer` |
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
| `~/.config/vdirsyncer/*.password` (`icloud`) | secrets — chmod 600, paste by hand |
| `~/.config/vdirsyncer/gmap.client_id`, `gmap.client_secret`, `*.token` | Google OAuth — chmod 600; see «Google calendars» below |
| `~/.config/vdirsyncer/config`, `~/.config/khal/config` | machine-local calendar wiring (iCloud `discover` + `gmap`/`gapm`/`gamp` pairs); recreate then `vdirsyncer discover`/`metasync` |
| Wallpaper image library | large binaries — copy separately |
| `~/applications/Cursor.AppImage` | binary not in git — `cursor-update --apply` after restore |
| `chromium-ffmpeg/` nested git | ignored; rebuild if needed |

After bootstrap, copy secrets/media yourself, then `exec fish`.

## Google calendars (`gmap`, `gapm`)

Both Gmail accounts sync through vdirsyncer's `google_calendar` storage, each in
its own pair and its own vdir root, so either can fail without touching iCloud or
«Уник». Consent needs a browser, so the first login is manual — until the token
exists `qs-calendar.sh sync` skips the pair entirely and the panel is unaffected.

1. Install the OAuth extra once: `uv tool install --force 'vdirsyncer[google]'`.
2. Google Cloud console → new project → enable the **CalDAV API** → create an
   OAuth client of type **Desktop app**.
3. Paste the two values (no quotes, no trailing newline needed) into:
   - `~/.config/vdirsyncer/gmap.client_id`
   - `~/.config/vdirsyncer/gmap.client_secret`

   One client serves both accounts; only the tokens differ.
4. Authorise each account once — this opens a browser and writes the token:
   - `vdirsyncer discover gmap` → sign in as **map07102007@gmail.com**
   - `vdirsyncer discover gapm` → sign in as **apm07102007@gmail.com**
5. `vdirsyncer sync gmap gapm && vdirsyncer metasync gmap gapm`

Each pair pins one remote calendar (the account's primary, where «Др отца» lives)
and renames it locally, so the vdirs stay at a fixed
`~/.local/share/calendars-g{map,apm}/g{map,apm}/` that `khal` and `qs-calendar.sh`
can hardcode. To follow a different Google calendar, change the third element of
that pair's `collections` entry to the calendar's id.

## Claude Code notifications

`~/.claude/settings.json` is not stowed (the app rewrites it). After a restore:

```bash
herdr integration install claude   # herdr agent state + toasts/sound
```

then add `~/.local/bin/claude-notify` as a `Stop` and `Notification` hook and set
`"preferredNotifChannel": "notifications_disabled"` (the hook replaces OSC 99, which
herdr swallows). The script skips Claude Desktop sessions (`CLAUDE_CODE_ENTRYPOINT`).
