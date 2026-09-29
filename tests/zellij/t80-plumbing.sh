#!/usr/bin/env bash
# Static plumbing checks for contracts (d) zellij-plugins-fetch and (e) repo
# wiring (restow/packages/bootstrap/KEYBINDS/kitty/tmux coexistence), plus
# plus a lint pass on the two remaining bin/ scripts and a real --check run.
#
#   T80_REPO=<dir>   an alternate repo root to check instead of this one
#                     (must have the same layout: restow.sh, packages/,
#                     bootstrap.sh, KEYBINDS.md, kitty/…, tmux/…, bin/…).
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"

TREPO="${T80_REPO:-$REPO}"
BIN_DIR="$TREPO/bin/.local/bin"

t_check "T80_REPO/restow.sh exists" test -f "$TREPO/restow.sh"

# (e) plumbing -----------------------------------------------------------------

if grep -qE '^\s*zellij\s*$' "$TREPO/restow.sh" 2>/dev/null; then
  t_ok "restow.sh packages=(...) lists zellij"
else
  t_fail "restow.sh packages=(...) lists zellij"
fi

if grep -qxF 'zellij' "$TREPO/packages/repo.txt" 2>/dev/null; then
  t_ok "packages/repo.txt lists zellij"
else
  t_fail "packages/repo.txt lists zellij"
fi

if grep -qxF 'zellij' "$TREPO/packages/rice-repo.txt" 2>/dev/null; then
  t_ok "packages/rice-repo.txt lists zellij"
else
  t_fail "packages/rice-repo.txt lists zellij"
fi

if grep -q 'zellij-plugins-fetch' "$TREPO/bootstrap.sh" 2>/dev/null; then
  t_ok "bootstrap.sh runs zellij-plugins-fetch"
else
  t_fail "bootstrap.sh runs zellij-plugins-fetch"
fi

if grep -qiE '^#+ .*zellij' "$TREPO/KEYBINDS.md" 2>/dev/null; then
  t_ok "KEYBINDS.md has a Zellij section"
else
  t_fail "KEYBINDS.md has a Zellij section"
fi

if grep -E 'ctrl\+alt\+n' "$TREPO/kitty/.config/kitty/kitty.conf" 2>/dev/null | grep -q 'NO_MUX=1'; then
  t_ok "kitty.conf's ctrl+alt+n map sets NO_MUX=1"
else
  t_fail "kitty.conf's ctrl+alt+n map sets NO_MUX=1"
fi

t_check "tmux/.tmux.conf still present (coexistence)" test -f "$TREPO/tmux/.tmux.conf"

if [ -f "$TREPO/fish/.config/fish/conf.d/00-mux-auto.fish" ] && \
   grep -q 'tmux' "$TREPO/fish/.config/fish/conf.d/00-mux-auto.fish" 2>/dev/null; then
  t_ok "00-mux-auto.fish keeps the tmux path (coexistence)"
else
  t_fail "00-mux-auto.fish keeps the tmux path (coexistence)"
fi

# (d) zellij-plugins-fetch ------------------------------------------------------

FETCH="$BIN_DIR/zellij-plugins-fetch"
BOOT="$BIN_DIR/zellij-boot"

for script in "$FETCH" "$BOOT"; do
  name="$(basename "$script")"
  if [ ! -f "$script" ]; then
    t_fail "$name exists" "not found at $script"
    continue
  fi
  t_check "$name is executable" test -x "$script"
  if out="$(shellcheck -x -P "$BIN_DIR" "$script" 2>&1)"; then
    t_ok "shellcheck clean: $name"
  else
    t_fail "shellcheck clean: $name" "$out"
  fi
done

# zjframes (frames only when a tab has 2+ panes) ships from the zjstatus release.
if grep -q 'zjframes.wasm https://github.com/dj95/zjstatus/releases/download/v0.25.0/zjframes.wasm 9d4a2aaf927fbb350dd3217b67d831390de36a7a367a42fd9b9ee3165b8256bf' "$FETCH" 2>/dev/null; then
  t_ok "zellij-plugins-fetch pins zjframes v0.25.0 by sha256"
else
  t_fail "zellij-plugins-fetch pins zjframes v0.25.0 by sha256"
fi
if grep -q 'file:~/.local/share/zellij/plugins/zjframes.wasm' "$TREPO/zellij/.config/zellij/config.kdl" 2>/dev/null; then
  t_ok "config.kdl loads zjframes from where the fetch script puts it"
else
  t_fail "config.kdl loads zjframes from where the fetch script puts it"
fi

if [ -x "$FETCH" ]; then
  if [ -d "$REAL_HOME/.local/share/zellij/plugins" ]; then
    mkdir -p "$XDG_DATA_HOME/zellij/plugins"
    cp "$REAL_HOME/.local/share/zellij/plugins"/*.wasm "$XDG_DATA_HOME/zellij/plugins/" 2>/dev/null
    if XDG_DATA_HOME="$XDG_DATA_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" "$FETCH" --check; then
      t_ok "zellij-plugins-fetch --check passes against a real-plugin-seeded HOME"
    else
      t_fail "zellij-plugins-fetch --check passes against a real-plugin-seeded HOME"
    fi
    # An empty plugin dir must fail --check (it's a real assertion, not a no-op).
    empty_dir="$T_ROOT/empty-plugins"
    mkdir -p "$empty_dir"
    if XDG_DATA_HOME="$empty_dir" XDG_CACHE_HOME="$T_ROOT/empty-cache" "$FETCH" --check 2>/dev/null; then
      t_fail "zellij-plugins-fetch --check fails when plugins are missing"
    else
      t_ok "zellij-plugins-fetch --check fails when plugins are missing"
    fi
  else
    t_fail "zellij-plugins-fetch --check against real plugins" "no plugins under $REAL_HOME/.local/share/zellij/plugins (run zellij-plugins-fetch)"
  fi
fi

t_done
