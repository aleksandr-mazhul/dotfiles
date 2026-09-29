#!/usr/bin/env bash
# Audit A1-A10 + decisions: config parses and carries the options we rely on.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config
CFG="$XDG_CONFIG_HOME/zellij/config.kdl"

t_check "config.kdl exists in the zellij stow package" test -f "$ZJ_PKG/config.kdl"

if command -v zellij >/dev/null; then
  if out="$(zellij --config-dir "$XDG_CONFIG_HOME/zellij" setup --check 2>&1)" && ! printf '%s' "$out" | grep -qiE 'error|failed to parse'; then
    t_ok "zellij setup --check accepts the config"
  else
    t_fail "zellij setup --check accepts the config" "$(printf '%s' "$out" | grep -iE 'error|parse' | head -3)"
  fi
else
  t_fail "zellij installed" "zellij not in PATH"
fi

# opt NAME VALUE : a top-level `NAME VALUE` line (quotes optional)
opt() {
  local name="$1" val="$2"
  if grep -qE "^[[:space:]]*${name}[[:space:]]+\"?${val}\"?[[:space:]]*(//.*)?$" "$CFG" 2>/dev/null; then
    t_ok "option $name $val"
  else
    t_fail "option $name $val" "not set in config.kdl"
  fi
}
opt mouse_mode true                          # A3
opt scroll_buffer_size 50000                 # A4
opt copy_command wl-copy                     # A6
opt copy_on_select true                      # A6
opt support_kitty_keyboard_protocol true     # A8 Shift+Enter
opt session_serialization true               # C4
opt serialize_pane_viewport true             # C4 pane contents
opt scrollback_lines_to_serialize 10000      # C4
opt serialization_interval 10                # H3 shutdown window
opt default_mode locked                      # B1 prefix model
opt theme ssot                               # G1
opt default_layout rice                      # C3
opt pane_frames true                         # focused pane must stand out (tmux pane-border-active)
opt pane_frame_style full                     # 0.45 default "titles" draws no border at all
opt scrollback_editor nvim                   # A5
opt show_startup_tips false                  # no popups over the first pane
opt show_release_notes false                 # (they steal focus from tests too)

# Keybinds must start from a clean slate (Q1): default modes steal Ctrl keys.
if grep -qE '^[[:space:]]*keybinds[[:space:]]+clear-defaults=true' "$CFG" 2>/dev/null; then
  t_ok "keybinds clear-defaults=true"
else
  t_fail "keybinds clear-defaults=true"
fi

# Live session: comes up locked (no mode stealing keys), truecolor env.
if zj_start; then
  # shellcheck disable=SC2016 # expanded by the shell inside zellij
  zj_type 'echo "CT=$COLORTERM"'; zj_enter
  assert_contains "panes see COLORTERM=truecolor (A1)" "$(zj_pane_screen)" "CT=truecolor"
  # Ctrl+P / Ctrl+T / Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+G / Ctrl+H / Ctrl+Q must
  # reach the shell: none of them may change the tab/pane structure.
  before="$(zj_layout | md5sum)"
  zj_keys_hex 10 14 0e 0f 13 07 08 11
  sleep 0.5
  assert_eq "default zellij mode keys do not fire in locked mode" "$(zj_layout | md5sum)" "$before"
  t_check "session still alive after Ctrl+Q" zj_ready
fi

t_done
