# Config coverage

Refreshed by `migration/inventory.sh` into `migration/inventory/`. Three destinations. Nothing in the archive column goes into git.

## Already in the repo

Stow links: hypr, quickshell, fish, kitty, nvim, kanata, gtk, waybar, waypaper, wofi, yazi, zellij, tmux, starship, fastfetch, matugen, vscode-ssot, vibepanel, voxtype, and the flag files. Zen is partial: `user.js`, chrome CSS, and userscripts are in git; the profile (logins, cookies) is not. OBS scenes are in git; the websocket password is not. Theme outputs (`bat`, `btop`, `cava`, `glow`, `peaclock`, `bottom`) are rebuilt by `theme-render`, so the live copies stay out of git.

## Settings to bring into Home Manager

Small files, no secrets:

- `autostart/` desktop entries (Spokenly, JetBrains Toolbox, Kontur Talk, vibe-typer)
- `mimeapps.list` (must stay a regular file, not a Stow symlink)
- `MangoHud/MangoHud.conf`
- `nwg-displays/` profiles (the live layout already lives in `hypr/.config/hypr/monitors.lua`)
- `lazydocker/config.yml`, `lact/ui.yaml`
- `OpenRGB/OpenRGB.json` (plugins stay packages, not this json if it embeds device state worth a look)
- `Thunar/accels.scm`, `Thunar/uca.xml`
- `wireplumber/wireplumber.conf.d`, `dunst/dunstrc.d`
- `dconf` user keys that are real preferences (the dump is `migration/inventory/dconf.ini`)
- `rice/vpn-favorites` if it has no account secrets
- `herdr/config.toml` only; skip sockets, logs, and `session.json`

## Encrypted archive only

`migration/backup-configs.sh` already packs these. Do not copy them into the flake:

- Browser profiles: `google-chrome`, `zen` profile, `yandex-browser`, Brave, Edge, Opera, Vivaldi, `mozilla`, `chromium`
- Editor and chat state: `Cursor`, `Code`, `Claude`, `Codex`, `JetBrains`, `discord`, `ktalk`, `obsidian`
- Secrets: `gh`, `vdirsyncer` tokens and passwords, `khal` (calendar accounts), `Windscribe`, `obs-record-toggle/password`, `cursor/auth.json`, `pulse/cookie`

## Left behind on purpose

Caches and package-manager state the apps rebuild: `Claude` and `Cursor` bulk data, `nvm`, `go`, `uv`, `nextjs-nodejs`, `yay`, `Docker Desktop`, `cosmic`, `Antigravity`, `Devin`, `configstore`, `github-copilot` cache. Empty dirs (`environment.d`, `mpv`, `nautilus`) get nothing.
