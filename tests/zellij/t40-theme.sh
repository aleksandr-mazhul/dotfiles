#!/usr/bin/env bash
# Audit C3/G1/G2: theme SSOT renders a zellij theme + layout, and the colors
# match what the SAME render wrote into the tmux theme (single source of
# truth). Overrides let this file be prototyped against a scratch theme-render
# and template set without ever touching the repo:
#   T40_THEME_RENDER  path to theme-render                (default: repo's)
#   T40_TEMPLATES     path to the theme templates dir      (default: repo's)
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"

T40_THEME_RENDER="${T40_THEME_RENDER:-$REPO/bin/.local/bin/theme-render}"
T40_TEMPLATES="${T40_TEMPLATES:-$REPO/theme/.config/theme/templates}"

ZTHEME="$XDG_CONFIG_HOME/zellij/themes/ssot.kdl"
ZLAYOUT="$XDG_CONFIG_HOME/zellij/layouts/rice.kdl"
TMUX_THEME="$XDG_CONFIG_HOME/tmux/theme-status.sh"

# zt_hex NAME : hex value of a THEME_COLORS[NAME]="#xxxxxx" line the render
# wrote into the tmux theme (the SSOT chrome tokens, read-only baseline).
zt_hex() {
  grep -oE "\\[$1\\]=\"#[0-9a-fA-F]{6}\"" "$TMUX_THEME" 2>/dev/null \
    | head -1 | grep -oE '#[0-9a-fA-F]{6}'
}

# --- stage inputs read-only: never let theme-render write into the real
# home or the repo. Only palette.toml (theme-render's actual input) and the
# template set are copied into the test's temp HOME. ---
mkdir -p "$XDG_CONFIG_HOME/theme/templates"
if [ -f "$REAL_HOME/.config/theme/palette.toml" ]; then
  cp "$REAL_HOME/.config/theme/palette.toml" "$XDG_CONFIG_HOME/theme/palette.toml"
else
  t_fail "REAL_HOME has a theme palette.toml to render from" "expected $REAL_HOME/.config/theme/palette.toml"
fi
if [ -d "$T40_TEMPLATES" ]; then
  cp -rL "$T40_TEMPLATES/." "$XDG_CONFIG_HOME/theme/templates/"
else
  t_fail "templates dir exists" "$T40_TEMPLATES not found"
fi

# --- render ---
if [ -f "$XDG_CONFIG_HOME/theme/palette.toml" ]; then
  t_check "theme-render exits 0" python3 "$T40_THEME_RENDER"
fi

t_check "zellij-theme.kdl.tmpl -> ~/.config/zellij/themes/ssot.kdl (C3/G1)" test -f "$ZTHEME"
t_check "zellij-layout.kdl.tmpl -> ~/.config/zellij/layouts/rice.kdl (C3/G1)" test -f "$ZLAYOUT"

if [ -f "$ZTHEME" ]; then
  assert_not_contains "themes/ssot.kdl has no unrendered {{ (G2)" "$(cat "$ZTHEME")" "{{"
  assert_contains "themes/ssot.kdl names the theme ssot (G1)" "$(cat "$ZTHEME")" "ssot {"
  t_check "themes/ssot.kdl opens a themes {} block" grep -qE '^[[:space:]]*themes[[:space:]]*\{' "$ZTHEME"
fi
if [ -f "$ZLAYOUT" ]; then
  assert_not_contains "layouts/rice.kdl has no unrendered {{ (G2)" "$(cat "$ZLAYOUT")" "{{"
  assert_contains "layouts/rice.kdl loads the zjstatus plugin (C3)" "$(cat "$ZLAYOUT")" "zjstatus.wasm"
fi

# --- colors: the SAME render's tmux output is the read-only baseline (G) ---
if [ -f "$TMUX_THEME" ] && [ -f "$ZLAYOUT" ]; then
  layout_body="$(cat "$ZLAYOUT")"
  for role in highlight-bg highlight-fg panel-bg panel-fg muted-bg muted-fg; do
    hex="$(zt_hex "chrome-$role")"
    if [ -z "$hex" ]; then
      t_fail "tmux theme has chrome-$role (baseline)" "not found in $TMUX_THEME"
      continue
    fi
    assert_contains "rice.kdl chrome-$role matches tmux SSOT ($hex) (G)" "$layout_body" "$hex"
  done
else
  t_fail "tmux theme rendered alongside (same-render baseline)" "$TMUX_THEME missing, or rice.kdl missing"
fi

# --- zellij accepts theme "ssot" + layout "rice" (C3/G1) ---
if command -v zellij >/dev/null && [ -f "$ZTHEME" ] && [ -f "$ZLAYOUT" ]; then
  mkdir -p "$XDG_CONFIG_HOME/zellij"
  CHECK_CFG="$XDG_CONFIG_HOME/zellij/config.kdl"
  printf 'show_startup_tips false\nshow_release_notes false\ntheme "ssot"\ndefault_layout "rice"\n' >"$CHECK_CFG"
  if out="$(timeout 15 zellij --config-dir "$XDG_CONFIG_HOME/zellij" setup --check 2>&1)" \
    && ! printf '%s' "$out" | grep -qiE 'error|failed to parse|not found'; then
    t_ok "zellij setup --check accepts theme ssot + layout rice (C3/G1)"
  else
    t_fail "zellij setup --check accepts theme ssot + layout rice (C3/G1)" "$(printf '%s' "$out" | head -5)"
  fi
elif ! command -v zellij >/dev/null; then
  t_fail "zellij installed" "zellij not in PATH"
else
  t_skip "zellij setup --check accepts theme ssot + layout rice" "themes/ssot.kdl or layouts/rice.kdl missing"
fi

t_done
