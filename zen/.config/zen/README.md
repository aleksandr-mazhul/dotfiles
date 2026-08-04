# Zen Browser — tracked prefs & shortcuts

Stowed to `~/.config/zen/`:

| File | Role |
| --- | --- |
| `zen-keyboard-shortcuts.json` | Zen keyboard shortcut map (canonical) |
| `user.js` | Safe startup prefs (compact UI, Vimium storage mode, …) |
| `vimium-options.json` | Vimium settings mirror (CSS still SSOT-rendered) |

`zen-browser` / `zen-bin` copy shortcuts + `user.js` into the active profile
on launch, and write shortcut edits back on exit.

Do **not** commit the full profile (`prefs.js`, `logins.json`, cookies, …).
