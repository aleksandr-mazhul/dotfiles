# Agent guide — this dotfiles repo

You are working in a GNU Stow–based Arch/Hyprland rice. Prefer small, reversible
changes. Never commit secrets (tokens, passwords, browser profiles, SSH keys).

## One-command restore (humans)

```bash
./bootstrap.sh
```

Details: [`RESTORE.md`](RESTORE.md), package lists: [`packages/`](packages/),
keybinds: [`KEYBINDS.md`](KEYBINDS.md).

## When installing a NEW application

Do all of the following in one session (or explain what you blocked on):

1. **Install**
   - Official: `sudo pacman -S --needed <pkg>`
   - AUR: tell the user to run `yay -S <pkg>` in their terminal if sudo/password is required from the agent.

2. **Register in inventory**
   ```bash
   ./packages/export.sh
   # or for a single known package:
   ~/.local/bin/dotfiles-register-app <pkg> [--aur]
   ```
   Commit updates to `packages/repo.txt` and/or `packages/aur.txt`.
   If it is part of the rice baseline, also add it to `packages/rice-repo.txt` or `packages/rice-aur.txt`.

3. **Track config (if any)**
   - Put files under the right Stow package, e.g. `misc/.config/<app>/…` or a new top-level package.
   - Add the package name to `restow.sh` `packages=(…)` if new.
   - Run `./restow.sh` (or stow that package) so `~/.config` links into the repo.
   - Do **not** vendor caches, cookies, `logs/`, `*.sqlite`, or credential files.

4. **Theme / colors (if the app is themable)**
   - Add `theme/.config/theme/templates/<app>.tmpl` using `{{ primary }}`, `{{ background }}`, …
   - Wire it in `bin/.local/bin/theme-render` `mapping` (or a small `_ensure_*` helper).
   - Run `theme-render` and verify.
   - Optional fish wrapper → `theme-rice.fish.tmpl` for toys that only take ANSI indices.


Cursor AppImage (Linux): install as a **real file**
`~/applications/Cursor.AppImage` (not a symlink to `Cursor-X.Y.Z.AppImage`).
Launch via stowed `~/.local/bin/cursor` (sets `APPIMAGE_EXTRACT_AND_RUN=1` so
the on-disk AppImage is not FUSE-mounted; `cursor-update` can replace it).

Auto-update: user timer `cursor-update.timer` runs `cursor-update --apply`
hourly (`CURSOR_UPDATE_POLICY=newest`). That does a **full download** replace,
which works when in-app AppImageUpdate cannot (signed→unsigned rollback —
“couldn't finish installing”). Track comes from `cursor.overlay.json`
(`update.releaseTrack`, rice default `latest`) or `CURSOR_RELEASE_TRACK`.
In-app AppImageUpdate (zsync) is unreliable (signed↔unsigned, empty `.upd_info`);
rice sets `update.mode` to `none` in `cursor.overlay.json` and uses the timer
instead. `cursor-update --check` prints remote version/signature/would-update.
Do **not** set `update.releaseTrack` to `dev` casually. Under FUSE
(`.mount_Cursor`) refuse replace; under extract-and-run atomic replace is
OK — fully quit and relaunch to load the new build.

5. **Binds / rules**
   - Hyprland: `hypr/.config/hypr/binds.lua` / `rules.lua` only when needed.
   - Kanata: `kanata/.config/kanata/kanata.kbd` for OS-level remaps.
   - Avoid double-binding the same chord (see Super+Shift+[ ] / Ctrl+Page_Up history).

6. **Commit**
   - Only when the user asks. Message style: conventional, focus on why.
   - Push only when asked.

## Stow layout

```
<package>/.config/...     → ~/.config/...
<package>/.local/bin/...  → ~/.local/bin/...
```

Generated SSOT outputs are rewritten by `theme-render`; keep **templates** in git,
not one-off machine copies (unless they are the stowed consumer like `gtk.css`).

## Hard no

- OBS `obs-websocket` password, `gh` `hosts.yml`, Zen full profile, `.env`, private keys
- `chromium-ffmpeg/` nested repo, `*.bak`, `.tmp-*`, `nvim.log`
- `git commit --amend` / force-push unless user rules explicitly allow
