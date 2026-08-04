# Theme SSOT — single source of truth for the desktop palette

Pipeline (via `apply-wallpaper-theme`):

1. `theme-extract` — weighted colors from wallpaper → `extract.json`
2. `theme-match` — pick curated harmony (sand-biased hybrid) → `match.json`
3. `theme-build` — full role map → **`palette.toml`** (canonical)
4. `theme-render` — templates → Kitty, Hypr, QS, GTK, starship, tmux, yazi, nvim, Vimium (Zen), btop, cava, peaclock, glow, bottom, rice fish wrappers, …

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
