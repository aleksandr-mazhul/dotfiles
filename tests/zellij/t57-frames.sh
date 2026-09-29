#!/usr/bin/env bash
# Which pane has focus must be obvious at a glance (tmux: pane-border-active
# vs -inactive). With 2+ panes every pane gets a rounded frame; the focused
# one is drawn in the theme's frame_selected color, the others in
# frame_unselected. A lone pane has no frame at all (zjframes): nothing to
# tell apart, and the border would only eat a row and two columns.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config
THEME="$XDG_CONFIG_HOME/zellij/themes/ssot.kdl"

# t57_color BLOCK : "r;g;b" of `base` inside the theme's BLOCK { } section
t57_color() {
  python3 - "$THEME" "$1" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
m = re.search(r'\b%s\s*\{[^}]*?base\s+"#([0-9a-fA-F]{6})"' % re.escape(sys.argv[2]), s)
if not m: sys.exit(1)
h = m.group(1)
print(";".join(str(int(h[i:i+2], 16)) for i in (0, 2, 4)))
PY
}
# t57_corner_rgb COL : fg color of the first rounded top-left corner at or
# after screen column COL on the frame row (row 1, under the bar)
t57_corner_rgb() {
  TM capture-pane -e -p -t drv | sed -n '2p' | python3 -c '
import re, sys
line = sys.stdin.read()
col, fg, out = 0, None, []
for tok in re.findall(r"\x1b\[[0-9;]*m|.", line):
    if tok.startswith("\x1b["):
        m = re.search(r"38;2;(\d+);(\d+);(\d+)", tok)
        if m: fg = ";".join(m.groups())
        continue
    if tok == "╭": out.append((col, fg))
    col += 1
want = int(sys.argv[1])
for c, f in out:
    if c >= want: print(f); break' "$1"
}

sel="$(t57_color frame_selected)" || sel=""
unsel="$(t57_color frame_unselected)" || unsel=""
if [ -n "$sel" ]; then t_ok "theme defines frame_selected"; else t_fail "theme defines frame_selected"; fi
if [ -n "$unsel" ]; then t_ok "theme defines frame_unselected"; else t_fail "theme defines frame_unselected"; fi
if [ -n "$sel" ] && [ "$sel" != "$unsel" ]; then t_ok "focused and unfocused frames differ in color"; else t_fail "focused and unfocused frames differ in color" "$sel vs $unsel"; fi

# never compare two empty strings as "equal colors"
[ -n "$sel" ] || sel=MISSING_SELECTED
[ -n "$unsel" ] || unsel=MISSING_UNSELECTED

t57_framed() { zj_screen | sed -n '2p' | grep -q '╭'; }
zj_need_plugins zjframes || { t_done; exit; }

if zj_start; then
  sleep 1                                     # zjframes applies on its first update
  if t57_framed; then t_fail "a single pane has no frame"; else t_ok "a single pane has no frame"; fi
  zj_keys_hex 02 7c                           # | : left + right, focus on the right
  if wait_for 3 t57_framed; then t_ok "frames appear as soon as there are two panes"; else t_fail "frames appear as soon as there are two panes"; fi
  sleep 0.3
  left="$(t57_corner_rgb 0)"; right="$(t57_corner_rgb 100)"
  assert_eq "frames on: the unfocused left pane has a frame_unselected border" "$left" "$unsel"
  assert_eq "the focused right pane has a frame_selected border" "$right" "$sel"
  zj_keys_hex 02 68; sleep 0.4                # h : focus left
  assert_eq "after moving focus left, the left frame lights up" "$(t57_corner_rgb 0)" "$sel"
  assert_eq "and the right frame dims" "$(t57_corner_rgb 100)" "$unsel"
  hl="$(t57_color frame_highlight)" || hl=MISSING_HIGHLIGHT
  zj_keys_hex 02                              # Ctrl+b: the focused frame signals the prefix
  assert_eq "after Ctrl+b the focused frame switches to frame_highlight" "$(t57_corner_rgb 0)" "$hl"
  zj_keys_hex 1b
  if zj_screen | sed -n '2p' | grep -q '╭'; then t_ok "corners are rounded"; else t_fail "corners are rounded"; fi
  assert_not_contains "frames do not repeat the session name" "$(zj_screen | sed -n '2p')" "$ZJ_S"
  zj_keys_hex 02 78                           # x : back to one pane
  if wait_for 3 sh -c "! tmux -S '$TM_SOCK' capture-pane -p -t drv | sed -n 2p | grep -q '╭'"; then
    t_ok "the frame goes away again with one pane left"
  else
    t_fail "the frame goes away again with one pane left"
  fi
fi

t_done
