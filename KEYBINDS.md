# Keybinds cheatsheet

Sources: `hypr/.../binds.lua`, `kitty.conf`, `nvim/.../keymaps.lua`, `kanata.kbd`, `gloview.lua`.

**Modifiers:** Alt = `mainMod` (skhd-style), Super = `secondMod`.  
Kitty also keeps default **Ctrl+Shift** (`kitty_mod`) shortcuts unless overridden below.  
VPN has no hotkey — use launcher (`vpn`) or QuickSettings.

> **Hide / show top bar:** `Super+B` (also `Super+Shift+B`)  
> Hidden = autohide; hover the top edge to peek (same as fullscreen). State is saved across reboots.

---

## Bar / overlays

| Keys | Action |
| --- | --- |
| Super+B | Toggle bar pinned ↔ autohide (hover peek) |
| Super+Shift+B | Same as Super+B |
| Super+Q | Clipboard history |
| Super+W | Wallpaper picker |
| Super+Shift+W | Random wallpaper |
| Super+Alt+W | Waypaper |
| Alt+O | App launcher |
| Ctrl+P | Overlay type filter (panel footers) |

## Windows

| Keys | Action |
| --- | --- |
| Ctrl+W | Close tab (tabbed apps) / close window |
| Ctrl+Q | Quit all windows of focused app |
| Super+Shift+Q | Force-kill focused window |
| Ctrl+N | New window of focused app |
| Alt+F | Fullscreen |
| Alt+Shift+F | Fullscreen (zoom) |
| Super+Shift+V | Toggle float |
| Super+Shift+P | Pin window |
| Ctrl+Alt+P | Pseudo-tile |
| Alt+H/J/K/L | Focus left/down/up/right |
| Alt+Shift+H/J/K/L | Move window |
| Alt+Ctrl+H/J/K/L | Swap window |
| Alt+- / Alt+= | Resize narrower / wider |
| Alt+LMB drag | Move window |
| Alt+RMB drag | Resize window |

## Tabbed stack (group)

| Keys | Action | Note |
| --- | --- | --- |
| Super+G | Mark / join / dissolve stack | 1st marks, 2nd joins, again dissolves |
| Super+Tab | Next tab in stack | |
| Super+Shift+Tab | Prev tab in stack | |

## Workspaces

| Keys | Action | Note |
| --- | --- | --- |
| Alt+letter | Focus workspace | W1 C2 V3 D4 G5 X6 Z7 E8 T9 I10 P11 Q12 U13 Y14 R15 A16 |
| Alt+Shift+letter | Move window to workspace (follow) | |
| Alt+Tab | Previous workspace | |
| Alt+S | Toggle special:magic | |
| Alt+Shift+S | Move to special:magic | |
| Alt+scroll | Next / prev workspace | |

## Monitors

| Keys | Action |
| --- | --- |
| Super+Alt+H/J/K/L | Focus monitor |
| Super+Alt+Shift+H/J/K/L | Move window to monitor |

## Overview (gloview)

| Keys | Action |
| --- | --- |
| Super+Up | Toggle overview |
| Super+Down | Close overview |
| Super+Left / Right | Prev / next in overview |

## Capture / annotate

| Keys | Action |
| --- | --- |
| Super+Shift+Ctrl+4 | Screenshot region |
| Super+T | OCR region |
| Super+Shift+R | OBS record toggle |
| Super+Alt+R | Open OBS |
| Super+D | Gromit draw toggle |
| Super+Shift+D | Gromit clear |
| Super+Ctrl+D | Gromit undo |
| Super+Alt+D | Gromit visibility |
| Super+Shift+L | Lock (hyprlock) |

## App tabs / Zoom

| Keys | Action | Note |
| --- | --- | --- |
| Super+Shift+[ / ] | Prev / next tab | kanata → Ctrl+PgUp/Dn |
| Ctrl+Shift+[ / ] | Prev / next tab (direct) | |
| Ctrl+PgUp / PgDn | Prev / next (after kanata) | |
| Ctrl+Shift+C | Yandex: copy page URL (else pass) | |
| Ctrl+K | Telegram: Esc to chat search (else pass) | |

## Nautilus (Finder-like, only when focused)

| Keys | Action |
| --- | --- |
| Ctrl+Backspace / Delete | Trash |
| Ctrl+Alt+Backspace / Delete | Delete forever |
| Ctrl+D | Duplicate |
| Ctrl+Shift+D | Bookmark |
| Ctrl+↑ / ↓ | Parent / Open |
| Ctrl+[ / ] | Back / Forward |
| Ctrl+Shift+G | Go to folder |
| Ctrl+I | Get Info |
| Ctrl+Shift+. | Toggle hidden |
| Ctrl+= / - | Zoom icons |

## Service mode

| Keys | Action |
| --- | --- |
| Alt+Shift+; | Enter service submap |
| Esc / Q / Enter | Exit service |
| R | Toggle split (then exit) |
| F | Toggle float (then exit) |
| Backspace | Close window (then exit) |
| H/J/K/L | Stack into group L/D/U/R (then exit) |

## Media / hardware

| Keys | Action |
| --- | --- |
| Vol ± / Mute / MicMute | Volume in **16 Mac-style steps** (~6%); mute toggle |
| Bright ± | Brightness in the **same 16-step grid** as volume |
| Media keys | playerctl next/pause/play/prev |

## Kitty (custom maps)

| Keys | Action |
| --- | --- |
| Ctrl+C | Copy |
| Ctrl+V | Paste |
| Super+C | Interrupt (SIGINT) |
| Ctrl+L | Clear terminal screen (shell); nvim window-right |
| Ctrl+PgUp / PgDn | tmux prev/next window |
| Ctrl+Shift+[ / ] | tmux prev/next window |
| Ctrl+Shift+H / L | tmux swap window left/right |
| Ctrl+= / - | Font zoom ± |
| Ctrl+Shift+C / V | Copy / paste (kitty_mod default) |

## Neovim (`keymaps.lua` + LazyVim)

| Keys | Action | Note |
| --- | --- | --- |
| Ctrl+H/J/K/L | Window focus (+ tmux navigate) | |
| Super+H | Focus file tree (open if needed) | kitty send_text → FocusFileTree() |
| Super+L | Focus code (leave tree) | kitty send_text → FocusCodeWindow() |
| Ctrl+arrows | Resize splits | |
| Super+V | Visual-block | Mac Ctrl+V → Super (Ctrl+V is terminal paste) |
| leader+gg | Lazygit (toggleterm) | |
| co / ct / cb / c0 | Conflict: ours / theirs / both / none | buffer-local in conflict |
| ]x / [x | Next / prev conflict | buffer-local |
| leader+gc o/t/b/0/n/p/l | Same + next/prev/list | git-conflict.nvim |
| leader+bd | Delete buffer | |
| leader+Tab+d | Close tab | |

## Kanata (hardware remap)

| Keys | Action |
| --- | --- |
| Caps tap / hold | Esc / Ctrl |
| HRM A S D F | Super Alt Ctrl Shift (hold) |
| HRM J K L ; | Shift Ctrl Alt Super (hold) |
| Ctrl+←/→ | Home / End (unless Alt also held) |
| Ctrl+↑/↓ | Doc begin / end |
| Alt+←/→ | → Ctrl+←/→ (word jump) |
| Alt+Backspace/Del | → Ctrl+Backspace/Del |
| Super+Shift+[ / ] | → Ctrl+PgUp / PgDn |
