# Theme SSOT — single source of truth for the desktop palette

Pipeline (via `apply-wallpaper-theme`):

1. `theme-extract` — weighted colors from wallpaper → `extract.json`
2. `theme-match` — pick curated harmony (sand-biased hybrid) → `match.json`
3. `theme-build` — full role map → **`palette.toml`** (canonical)
4. `theme-render` — templates → Kitty, Hypr, QS, GTK/Files, VS Code/Cursor, Obsidian, starship, tmux, yazi, nvim, Vimium (Zen), btop, cava, peaclock, glow, bottom, rice fish wrappers, …

    Edit accents families in `harmonies.toml`. Do not hardcode hex in apps.

### Rice CLI toys

| Tool | How SSOT applies |
| --- | --- |
| `cava` | `~/.config/cava/themes/ssot` + `theme = 'ssot'` |
| `peaclock` | `~/.config/peaclock/config` (fish wraps `--config-dir`) |
| `glow` / `GLAMOUR_STYLE` | `~/.config/glow/ssot.json` |
| `btm` | `~/.config/bottom/bottom.toml` |
| `cbonsai` / `tty-clock` / `pipes.sh` | fish wrappers with palette→ANSI indices |
| `gum` | `GUM_*_FOREGROUND` env from `theme-rice.fish` |

Reload fish (`exec fish`) after a wallpaper change so wrappers pick up new indices.

### VS Code / Cursor

`theme-render` writes extension `dotfiles-ssot` into `~/.vscode/extensions` and
`~/.cursor/extensions`, then sets `workbench.colorTheme` to **SSOT**. Reload the
window once after the first install (`Ctrl+Shift+P` → Developer: Reload Window).

Shared editor settings / keybindings / marketplace extensions live in
`~/.config/vscode-ssot` (stow package `vscode/`). systemd user unit
`vscode-cursor-sync.path` mirrors theme, settings, and new plugins both ways
(`vscode-cursor-sync --auto`). Cursor-only keys stay in `cursor.overlay.json`.
Do not copy `anysphere.*` into VS Code, or Microsoft remotes into Cursor.
Pylance is VS Code-only (`extensions-code.txt`); Cursor uses bundled
`anysphere.cursorpyright` (`extensions-cursor.txt`). Activity Bar pin order
is `activity-bar.json`. Wallpaper `theme-render` still writes the **SSOT**
color theme into both editors; picking another theme in either app is then
mirrored.

### GNOME Files (Nautilus)

GTK 3/4 `gtk.css` maps libadwaita named colors (`window_bg_color`, `accent_bg_color`,
sidebar, …) from `palette.toml`. `nautilus-dark` unsets Graphite so Files reads
`~/.config/gtk-4.0/gtk.css`. Restart Nautilus after a wallpaper change.

### Obsidian

A `ssot.css` snippet is written into each vault from `obsidian.json` and enabled.
Accent color is patched in `.obsidian/appearance.json`. Reopen or switch theme
once if the snippet does not pick up immediately.

### Vimium (Zen)

Vimium stores CSS in Firefox **`chrome.storage.sync`** →
`~/.config/zen/<profile>/storage-sync-v2.sqlite` (not only `storage.js`).

`theme-render` / `theme-vimium` update that DB. The `zen-browser` launcher runs
the sync **before** Zen starts (DB must not be locked by a running browser).

## Chrome tokens (`[chrome]`)

Shared fills/fonts for bars and widgets (tmux tabs, starship powerline, QS):

| Token | Role | Maps to |
| --- | --- | --- |
| `highlight_bg` / `highlight_fg` | Highlight pill | `primary` / `on_primary` |
| `panel_bg` / `panel_fg` | Secondary segment | `surface_container_high` / `secondary` |
| `muted_bg` / `muted_fg` | Tertiary segment | `surface_container` / `tertiary` |
| `font_mono` / `font_ui` | Widget fonts | JetBrains Mono |

### tmux window tabs

| Segment | bg | fg |
| --- | --- | --- |
| Active index + name | `chrome_highlight_bg` | `chrome_highlight_fg` |
| Inactive index | `chrome_muted_bg` | `chrome_muted_fg` |
| Inactive name | `chrome_panel_bg` | `chrome_panel_fg` |

### starship

| Segment | tokens |
| --- | --- |
| Path | highlight |
| Branch | panel |
| Time | muted |
