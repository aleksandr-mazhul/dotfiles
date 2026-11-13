#!/usr/bin/env bash
# Pack every app config that git does NOT hold into ONE passphrase-encrypted
# file (age): ~/.config leftovers (Zen, Chrome, Discord, JetBrains, Claude, ...),
# home dotfiles, small ~/.local/share state, GPG keys and NetworkManager
# connections. Caches, logs and files over MAX_MB are dropped: that is data,
# and apps rebuild it. Things already stowed from this repo are symlinks and
# are skipped. Plaintext is staged on tmpfs only.
#
# Usage: backup-configs.sh [--dry-run] <dest-dir>   (dest should be on another disk)
set -euo pipefail

MAX_MB=50

# Roots to scan, relative to $HOME. Missing ones are ignored.
ROOTS=(
  .config
  .zshrc .bashrc .bash_profile .profile .npmrc .ideavimrc .vim
  .ssh .gnupg .password-store .kube .keychain .pki .ansible
  .aider .aider.conf.yml .claude .claude.json .codex .gemini .qwen .copilot
  .agents .devin .devin-shared .junie .codeium .thunderbird
  .docker/config.json .docker/daemon.json .docker/contexts
  .cursor/mcp.json .cursor/argv.json .vscode/argv.json
  .local/share/keyrings .local/share/fish .local/share/zoxide
  .local/share/applications .local/share/icons .local/share/themes
  .local/share/tmux .local/share/k9s .local/share/qalculate .local/share/nwg-look
  .local/share/Vial .local/share/tailscale .local/share/Windscribe
  .local/share/gitflow .local/share/gitflow-backup .local/share/opencode
  .local/share/hyprland .local/share/nautilus .local/share/vdirsyncer
  .local/share/calendars .local/share/calendars-gmap .local/share/calendars-gapm
  .local/share/user-places.xbel
)

# Skipped entirely: settings already live in git (vscode-ssot) or it is all data.
PRUNE_PATHS=(
  .config/Cursor .config/Code .config/zen/chrome
  .claude/plugins/cache .claude/plugins/marketplaces
  .codex/sessions .codex/archived_sessions .codex/log .codex/.tmp .codex/cache
  .codex/plugins/cache .codex/plugins/.plugin-appserver
  .config/Claude/vm_bundles .claude/context-mode
  # Browser extension code is re-fetched by sync; their settings stay.
  .config/google-chrome/Default/Extensions .config/yandex-browser/Default/Extensions
  # Per-site data (IndexedDB, localStorage): data, not configuration.
  '.config/zen/*/storage' '.config/mozilla/firefox/*/storage'
  # Downloaded app payloads (Discord modules, Codex runtimes).
  '.config/discord/app-*' .config/Codex/artifact-sessions
)
# Directory names that are caches/transcripts anywhere in the tree.
PRUNE_NAMES=(
  Cache 'Code Cache' GPUCache DawnCache GrShaderCache ShaderCache GraphiteDawnCache
  CacheStorage 'Service Worker' cache2 startupCache Crashpad 'Crash Reports' logs Logs
  blob_storage node_modules __pycache__ .git
  IndexedDB extensions_crx_cache component_crx_cache CachedData WasmTtsEngine WidevineCdm grazie
  AsrSubtitles autofill_tfl_predictions 'Safe Browsing' 'Sync Data'
  file-history shell-snapshots todos statsig telemetry session-env paste-cache image-cache
)

dry=0
[ "${1:-}" = "--dry-run" ] && { dry=1; shift; }
dest="${1:?usage: backup-configs.sh [--dry-run] <dest-dir>}"

# NUL-separated list of regular files to pack, relative to $HOME.
select_files() {
  local -a roots=() prune=()
  local r p n
  for r in "${ROOTS[@]}"; do [ -e "$HOME/$r" ] && roots+=("$r"); done
  for p in "${PRUNE_PATHS[@]}"; do prune+=(-path "$p" -o); done
  for n in "${PRUNE_NAMES[@]}"; do prune+=(-name "$n" -o); done
  unset 'prune[-1]'
  (cd "$HOME" && find "${roots[@]}" \( "${prune[@]}" \) -prune -o \
    -type f -size -"${MAX_MB}"M ! -name '*.jsonl' ! -name '*.log' -print0 2>/dev/null)
}

if [ "$dest" = "--list" ]; then # print the selection, one path per line
  select_files | tr '\0' '\n'
  exit 0
fi

home_dev="$(df --output=source "$HOME" | tail -1)"
dest_dev="$(df --output=source "$(dirname "$dest")" 2>/dev/null | tail -1 || true)"
[ "$home_dev" = "$dest_dev" ] && echo "WARNING: $dest is on the same disk as \$HOME ($home_dev)" >&2

list="$(mktemp)"
trap 'rm -f "$list"' EXIT
select_files >"$list"

sizes="$(cd "$HOME" && xargs -0 -a "$list" stat -c '%s %n' 2>/dev/null)"
echo "selected: $(tr -cd '\0' <"$list" | wc -c) files, $(awk '{s+=$1} END {printf "%.0f", s/1048576}' <<<"$sizes") MB total"
echo "by group (top 25):"
awk '{ s=$1; $1=""; sub(/^ /,""); n=split($0,a,"/"); k=a[1]; if (k==".config"||k==".local"||k==".docker"||k==".cursor") k=a[1]"/"a[2]; if (k==".local") k=k"/"a[3]; g[k]+=s }
     END { for (k in g) printf "%8.1f MB  %s\n", g[k]/1048576, k }' <<<"$sizes" | sort -rn | head -25
[ "$dry" -eq 1 ] && exit 0

mkdir -p "$dest"
stage="$(mktemp -d -p "${XDG_RUNTIME_DIR:-/dev/shm}" configs.XXXXXX)"
trap 'rm -f "$list"; rm -rf "$stage"' EXIT
chmod 700 "$stage"

gpg --export-secret-keys --armor >"$stage/gpg-secret-keys.asc"
gpg --export-ownertrust >"$stage/gpg-ownertrust.txt"
sudo cp -a /etc/NetworkManager/system-connections "$stage/nm-connections"
sudo chown -R "$(id -u):$(id -g)" "$stage/nm-connections"
(cd "$HOME" && xargs -0 -a "$list" stat -c '%s %n') >"$stage/MANIFEST.txt"

out="$dest/configs-$(date +%F).tar.age"
rm -f "$out"
# Running apps delete temp files (SQLite -wal/-shm, blobs) between the scan and
# the read; --ignore-failed-read keeps those from failing the whole backup.
tar -cf - --ignore-failed-read -C "$HOME" --null -T "$list" -C "$stage" . | age -p -o "$out"

sha256sum "$out"
echo "verify: age -d $out | tar -tv | head"
