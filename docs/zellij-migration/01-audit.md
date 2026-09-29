# Zellij migration — stage 1: tmux audit

Branch `feat/zellij-herdr`. Source of truth: everything in the repo that
touches tmux (`grep -ril tmux`, 31 files, all reviewed). Target: zellij 0.45.x
(`extra/zellij`, not installed yet). tmux stays working in parallel until the
cut-over.

Legend: **[P]** port to zellij · **[R]** re-wire a consumer · **[D]** drop /
not needed · **[?]** open question for the user.

## A. Core options — `tmux/.tmux.conf`

| # | tmux | What it does | Zellij plan |
|---|---|---|---|
| A1 | `default-terminal tmux-256color`, `terminal-overrides …:RGB` | truecolor | [P] zellij does truecolor natively; verify `COLORTERM` in panes |
| A2 | `base-index 1`, `pane-base-index 1`, `renumber-windows on` | tabs numbered from 1, no gaps | [P] zellij tabs are 1-based and renumber themselves; verify |
| A3 | `mouse on` | mouse | [P] `mouse_mode true` |
| A4 | `history-limit 50000` | scrollback | [P] `scroll_buffer_size 50000` |
| A5 | `mode-keys vi` | vi copy-mode | [P] scroll/search mode keys hjkl/v/y; `scrollback_editor` = nvim |
| A6 | `set-clipboard on` + `copy-pipe wl-copy` (y, mouse drag) | clipboard | [P] `copy_command "wl-copy"`, `copy_on_select true` |
| A7 | `allow-passthrough on` | OSC 52, **OSC 99 Claude notifications**, focus | [P]+[?] zellij forwards OSC 52; OSC 99 is not passed through — `claude-notify` already bypasses it (see F2), verify |
| A8 | `extended-keys always` + `csi-u` + `extkeys` | **Shift+Enter → CSI 13;2u** reaches Claude Code | [P] `support_kitty_keyboard_protocol true`; test that Shift+Enter still reaches the pane as newline |
| A9 | `focus-events on` | nvim autoread etc. | [P] verify zellij forwards focus-in/out |
| A10 | `escape-time 10` | fast ESC in nvim | [P] zellij has no ESC delay; verify |

## B. Keys — `tmux/.tmux.conf`

Prefix model: `C-b` (mouse macro pad "service mode") + `C-a` (legacy Mac).

| # | tmux key | Action | Zellij plan |
|---|---|---|---|
| B1 | prefix `C-b`, prefix2 `C-a`, `C-b C-b`/`C-a C-a` send-prefix | prefix | [P]+[?] zellij "tmux mode" entered by Ctrl+b; add Ctrl+a as a second entry; double-press sends the literal key. Default zellij modes (Ctrl+p/t/n/s/o/g/h/q) **clash with shell/nvim** → see Q1 |
| B2 | `\|` / `-` | split right / down | [P] `NewPane "Right"` / `"Down"` |
| B3 | `r` | reload config | [D] zellij hot-reloads config.kdl on save |
| B4 | `D`, `C-D`, `C-S-D` unbound | no kill-window by accident (commit d1aec2a) | [P] make sure nothing in tmux-mode kills a tab on D |
| B5 | `c` | new window | [P] `NewTab` |
| B6 | `C` | prompt → new session | [P] session-manager plugin or `zellij attach -c` prompt |
| B7 | `h/j/k/l` | select pane | [P] `MoveFocus` |
| B8 | `H`/`L`, `M-H`/`M-L` (from kitty Ctrl+Shift+H/L) | swap window left/right | [P] `MoveTab "Left"/"Right"` in tmux-mode + global `Alt Shift h/l` |
| B9 | `C-S-Left` / `C-S-Right` | prev/next window | [P] `GoToPreviousTab`/`GoToNextTab` |
| B10 | prefix `p` / `n` (kitty Ctrl+PgUp/Dn, Ctrl+Shift+[ ]) | prev/next window | [P] tmux-mode `p`/`n` → tab prev/next **or** re-point kitty to a non-prefix sequence (see E1) |
| B11 | `-r` arrows | resize pane by 2 | [P] resize in tmux-mode (repeatable: stay in mode) |
| B12 | `f` | zoom pane | [P] `ToggleFocusFullscreen` |
| B13 | `v` + copy-mode `v`/`y` | copy mode | [P] `SwitchToMode "Scroll"` + select/copy |
| B14 | `M-c` | attach with cwd = current pane | [D]/[?] no direct analogue; zellij panes already open in current cwd |
| B15 | `C-s` | manual save | [P] zellij autosaves; map to a no-op or `zellij action dump-layout` backup |
| B16 | `C-r` (resurrect default) | manual restore | [P] session-manager "resurrect" tab |
| B17 | `M-h/j/k/l` (vim-tmux-navigator) | Super+hjkl crosses nvim splits ↔ panes | [P] see D |
| B18 | tmux defaults still in use: `d` detach, `x` kill pane, `,` rename, `w` choose tree, `s` sessions, `0-9` select window, `z` zoom, `[` copy | muscle memory | [P] same letters in tmux-mode (`d` Detach, `x` CloseFocus, `,` RenameTab, `w`/`s` session-manager, `1-9` GoToTab, `z` fullscreen, `[` Scroll) |

## C. Plugins

| # | Plugin | Zellij plan |
|---|---|---|
| C1 | tpm | [D] zellij plugins are wasm, loaded by URL/path in config |
| C2 | vim-tmux-navigator | [P] see D |
| C3 | tmux-tokyo-night / PowerKit, status **top**, rounded edges, index strip, no right widgets | [P] `zjstatus` wasm plugin in a default layout at top; colors from SSOT (G) |
| C4 | tmux-resurrect (+ pane contents, nvim session strategy, `@resurrect-processes "~npm run" "claude->claude --continue"`) | [P]+[?] built-in `session_serialization true`, `serialize_pane_viewport true`, `scrollback_lines_to_serialize`. Resurrected commands wait for Enter unless … → Q3 |
| C5 | tmux-continuum (5 min tick) | [D] zellij serializes on its own interval (`serialization_interval`) |

## D. Seamless navigation nvim ↔ multiplexer (highest-risk item)

Chain today: kitty `super+j/k` → `ESC j/k`; `super+h/l` → `focus_nvim_pane.py`
→ in nvim: `FocusFileTree`/`FocusCodeWindow`, otherwise `ESC h/l` → tmux
`M-hjkl` (vim-tmux-navigator: nvim split if possible, else tmux pane).

| # | File | Zellij plan |
|---|---|---|
| D1 | `.tmux.conf` navigator mapping `M-hjkl`, unbind `C-hjkl` | [P] zellij: `Alt h/j/k/l` → `vim-zellij-navigator` (wasm) or `MoveFocusOrTab`, passes key to nvim when nvim is focused |
| D2 | `nvim/.config/nvim/lua/plugins/super-nav.lua` (vim-tmux-navigator spec) | [R] add zellij-aware plugin (`swaits/zellij-nav.nvim` or equivalent), keep tmux one while both coexist, pick by `$ZELLIJ` vs `$TMUX`; `lazy-lock.json` changes with it |
| D3 | `nvim/…/config/keymaps.lua` `<M-hjkl>` → `TmuxNavigate*`, `tree_escape` → `tmux select-pane`, `<D-l>/<F14>` → `TmuxNavigateRight` | [R] abstract "navigate or leave" behind one function that dispatches to tmux or zellij (`zellij action move-focus`) |
| D4 | `super-nav.lua` snacks picker `<m-hjkl>` | [R] same abstraction |
| D5 | `kitty/…/focus_nvim_pane.py` — "not nvim (e.g. tmux)" forwards `ESC h/l`; under zellij `foreground_cmdline` is `zellij`, so it always forwards — same as tmux | [R] verify only, update comment |

## E. Kitty — `kitty/.config/kitty/kitty.conf`

| # | Map | Zellij plan |
|---|---|---|
| E1 | `ctrl+page_up/down`, `ctrl+shift+[ ]` → `\x02p` / `\x02n` (prefix p/n) | [R] works if tmux-mode has `p`/`n`; cleaner: send `Alt [`/`Alt ]`-style sequence bound globally in zellij. Must stay **single path** (kanata already maps Super+Shift+[ ] → Ctrl+PgUp/Dn; hypr must not bind them) |
| E2 | `ctrl+shift+h/l` → `ESC H` / `ESC L` | [P] zellij `Alt Shift h/l` → MoveTab |
| E3 | `super+h/l` kitten, `super+j/k` → `ESC j/k` | [P] via D1 |
| E4 | `shift+enter` → `\x1b[13;2u` "even under tmux/herdr" | [P] verify under zellij (A8) |
| E5 | `ctrl+alt+n` → new window with `NO_TMUX=1` | [R] rename/extend env var (`NO_MUX=1`, keep `NO_TMUX` compat) |
| E6 | `clipboard_control …` comment "nvim/tmux OSC52" | [R] comment only |
| E7 | `notify_on_cmd_finish unfocused` + comment "OSC 99 via tmux passthrough" | [R] verify, fix comment |

## F. Shell, notifications, agents

| # | Item | Zellij plan |
|---|---|---|
| F1 | `fish/conf.d/00-tmux-auto.fish`: auto-attach in kitty only (skip IDE, SSH, nested, `NO_TMUX`), boot.sh restore, attach to last-focused session | [P] new `00-zellij-auto.fish`: same guards + `$ZELLIJ` nested check, `zellij attach -c <name>`; switch between the two by one variable (Q4) |
| F2 | `bin/claude-notify` — talks to notify daemon directly, "works in kitty, tmux, herdr" | [R] mux-agnostic already; verify in zellij, update comment. Optional: focus-on-click → `zellij action go-to-tab` |
| F3 | `fish/conf.d/history-persist.fish` "shared across tmux panes" | [R] comment only; behaviour is mux-agnostic |
| F4 | `~/.claude/hooks/herdr-agent-state.sh` (Claude SessionStart hook) | [D] herdr-only, out of scope for this stage |

## G. Theme SSOT

| # | Item | Zellij plan |
|---|---|---|
| G1 | `theme/templates/tmux-theme.sh.tmpl` → `~/.config/tmux/theme-status.sh` (PowerKit chrome: highlight/panel/muted) | [P] new `zellij-theme.kdl.tmpl` (zellij `themes {}` block) + zjstatus colors from the same chrome tokens |
| G2 | `bin/theme-render` mapping + PowerKit cache bust | [R] add zellij mapping; zellij hot-reloads the theme file |
| G3 | `bin/apply-wallpaper-theme` — `tmux source-file` after re-theme | [R] zellij: nothing to reload (file watch) — verify live recolor |
| G4 | `_theme_core.py`, `quickshell Theme.qml/Colors.qml`, `theme/templates/quickshell-colors.qml.tmpl` comments "same language as tmux" | [R] comments only |

## H. Persistence & lifecycle (tmux-specific machinery)

| # | Item | Zellij plan |
|---|---|---|
| H1 | `tmux/.config/tmux/boot.sh` — flock, server in `tmux-server.scope` `Before=tmux-save.service`, restore `last`, remember focused session | [D]/[P] zellij resurrects sessions itself (`zellij attach <dead-session>`); keep flock-guarded "attach last session" logic in the fish hook |
| H2 | `tmux-save.sh` (lock, debounce, same-second bug, self-heal) | [D] resurrect-specific; zellij serializes internally |
| H3 | `systemd/user/tmux-save.service` (save on shutdown) | [?] zellij writes on its interval + on exit; verify a reboot keeps the last layout; add a unit only if needed |
| H4 | `@resurrect-processes`: `npm run …`, `claude --continue` | [?] Q3 |

## I. Repo plumbing & docs

| # | Item | Plan |
|---|---|---|
| I1 | `restow.sh` packages list | [R] add `zellij` |
| I2 | `packages/repo.txt`, `rice-repo.txt` | [R] add `zellij` (tmux stays until cut-over) |
| I3 | `bootstrap.sh` tpm install, `tmux-save.service` enable, summary text | [R] zellij plugin fetch (zjstatus/navigator wasm) + text |
| I4 | `KEYBINDS.md` Kitty rows "tmux prev/next/swap", nvim "tmux navigate" | [R] zellij section |
| I5 | `README.md`, `RESTORE.md`, `theme/README.md`, `docs/keybinds-cheatsheet.canvas.tsx` | [R] mentions |
| I6 | `kanata.kbd`, `hypr/binds.lua` comments about tmux window skipping | [R] comments only; the rule "one path for Ctrl+PgUp/Dn" still holds |
| I7 | `tmux/.config/tmux/linux.conf` (`@copy_command`, prefix notes) | [D] folded into A6/B1 |
| I8 | stale: tmux.conf says "Super+B via kitty" — no such map exists anywhere | [D] do not port |

## Found after the first pass (review, 2026-09-26)

| # | tmux | Zellij plan |
|---|---|---|
| B19 | `automatic-rename` (tmux default, never disabled): window name = foreground command, shown as `#W` | [P] `fish/conf.d/zellij-tab-name.fish` renames the pane's own tab on preexec/postexec; hand-renamed tabs are left alone (tmux turns automatic-rename off on rename-window) — `t35` |
| B20 | prefix works inside copy-mode (kitty's Ctrl+PgUp/Dn = prefix+p/n) | [P] Ctrl+b/Ctrl+a enter tmux-mode from scroll/search too — `t55` |
| B21 | an unbound key after the prefix just cancels it | [P] every remaining printable key is bound to "back to locked"; zjstatus also shows a TMUX/SCROLL/SEARCH/RENAME pill — `t11`, `t55` |
| B22 | tmux stock prefix table: `o ; { } ! Space & $ t ? PageUp` | [P] FocusNextPane, FocusLastPane, MovePane(Backwards), BreakPane, NextSwapLayout (stock swap layouts in rice.kdl), close-tab with y/N prompt, session-manager, peaclock, cheatsheet in glow, scroll+page-up — `t11` |
| B23 | zellij extras on free letters: `Tab g e S y` | [P] last tab, floating layer, float/embed, sync panes, copy last command output — `t11` (y: manual, needs clipboard) |
| A5b | copy-mode-vi `v`/`y` keyboard selection | [D] zellij has no keyboard selection: `e` opens scrollback in nvim, mouse drag copies — documented in KEYBINDS.md |

**Not testable headlessly — manual smoke in real kitty:** A7 (OSC 52 from nvim,
OSC 99 from Claude Code; `claude-notify` does not depend on it), A9 (focus
events → nvim autoread), E3/D5 (kitty's `focus_nvim_pane.py` kitten under
zellij), H3 (state after a real reboot).

## Decisions (2026-09-26)

- Q1 → tmux-mode on Ctrl+b (+Ctrl+a), `clear-defaults`, same letters as today, plus global Alt navigation.
- Q2 → zjstatus at top, PowerKit look, colors from theme SSOT.
- Q3 → auto-restart `claude --continue` and `npm run …` after restore (wrapper needed).
- Q4 → coexist behind `MUX=zellij|tmux`; remove tmux in a separate final commit.

## Open questions (as asked)

- **Q1 prefix model.** Zellij's default mode keys (Ctrl+p/t/n/s/o/h/g/q) steal
  keys from fish and nvim. Proposal: `clear-defaults=true`, one **tmux-mode on
  Ctrl+b (+Ctrl+a)** with the same letters as today, plus a few global Alt
  binds (navigation, tab move). Everything else stays locked.
- **Q2 status bar.** zjstatus at top, look copied from PowerKit (rounded
  pills, index strip, no right widgets) — or zellij's default tab-bar?
- **Q3 restoring `npm run` / `claude --continue`.** Zellij restores commands
  but by default waits for Enter in each pane. Accept that, or add a wrapper so
  `claude` panes resume automatically?
- **Q4 cut-over.** Coexist with a switch (`MUX=zellij|tmux` in fish) until the
  tests are green, then delete the tmux package in a separate commit?
