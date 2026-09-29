#!/usr/bin/env bash
# The session-manager (Ctrl+b s / w / C -> new session) starts sessions with
# the layout named "default", not config.kdl's default_layout. Without our own
# layouts/default.kdl such sessions get zellij's stock tab-bar + status-bar.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config
zj_need_plugins zjstatus || { t_done; exit; }

t_check "layouts/default.kdl exists in the package" test -e "$ZJ_PKG/layouts/default.kdl"

if zj_start --new-session-with-layout default; then
  sleep 1
  plugins="$(zj_panes_json | python3 -c 'import json,sys; print(" ".join(sorted({(p.get("plugin_url") or "").split("/")[-1] for p in json.load(sys.stdin) if p["is_plugin"]})))')"
  assert_contains "a --layout default session gets the zjstatus bar" "$plugins" "zjstatus.wasm"
  assert_not_contains "and not zellij's stock tab-bar" "$plugins" "tab-bar"
  assert_not_contains "and not zellij's stock status-bar" "$plugins" "status-bar"
fi

t_done
