# Zen Browser — tracked prefs & shortcuts

Stowed to `~/.config/zen/`:

| File | Role |
| --- | --- |
| `zen-keyboard-shortcuts.json` | Zen keyboard shortcut map (canonical) |
| `user.js` | Safe startup prefs (compact UI, userChrome enable, Vimium storage mode, …) |
| `vimium-options.json` | Vimium settings mirror (CSS still SSOT-rendered) |
| `chrome/userChrome.css` | Liquid-glass chrome; selected tab = hover highlight (copied into profile) |
| `chrome/autoscroll.*` | Middle-click autoscroll origin (glass disc; copied into profile) |

`zen-browser` / `zen-bin` copy shortcuts + `user.js` + `chrome/userChrome.css`
(+ autoscroll assets) into the active profile on launch, and write shortcut
edits back on exit. Restart Zen after editing `userChrome.css`.

Do **not** commit the full profile (`prefs.js`, `logins.json`, cookies, …).
