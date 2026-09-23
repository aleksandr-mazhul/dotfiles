#!/usr/bin/env bash
# Restow all dotfiles packages into $HOME (GNU Stow)
# Usage: ./restow.sh            # conflicting real files -> ~/.dotfiles-backup/<ts>/
#        ./restow.sh --adopt    # pull live edits INTO the repo (this machine only)
#        ./restow.sh --check    # only report what is not linked; changes nothing
#
# Default never touches the repo: on a fresh machine, --adopt would copy the
# apps' default configs over the tracked ones. Use --adopt only where the live
# files are yours, then review `git diff`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${HOME}"
cd "$ROOT"

ADOPT=0
CHECK=0
case "${1:-}" in
  --adopt) ADOPT=1 ;;
  --check) CHECK=1 ;;
  "") ;;
  -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
  *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

BACKUP="$TARGET/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
# Move a live path aside instead of deleting it. $1 is relative to $TARGET.
backup() {
  local rel="$1"
  [[ -e "$TARGET/$rel" || -L "$TARGET/$rel" ]] || return 0
  mkdir -p "$BACKUP/$(dirname "$rel")"
  mv "$TARGET/$rel" "$BACKUP/$rel"
  echo "  backup ~/$rel -> $BACKUP/$rel"
}

packages=(
  bin
  entropy
  fastfetch
  fish
  git
  gtk
  herdr
  hypr
  kanata
  kitty
  matugen
  misc
  nvim
  nwg-look
  obs
  quickshell
  starship
  theme
  tmux
  vibepanel
  vscode
  waybar
  waypaper
  wofi
  x11
  xsettingsd
  yazi
  zen
)

verify() {
  echo "==> Verify (every tracked file must resolve into the repo)"
  ok=0; bad=0
  for pkg in "${packages[@]}"; do
    [[ -d "$pkg" ]] || continue
    while IFS= read -r f; do
      rel="${f#"$pkg"/}"
      [[ "$rel" == .config/mimeapps.list ]] && continue   # copied on purpose, see below
      [[ "$(basename "$rel")" == .stow-local-ignore ]] && continue
      if [[ "$(readlink -f "$TARGET/$rel" 2>/dev/null)" == "$ROOT/$f" ]]; then
        ok=$((ok + 1))
      else
        bad=$((bad + 1))
        if [[ -L "$TARGET/$rel" || ! -e "$TARGET/$rel" ]]; then
          echo "  MISS ~/$rel"
        else
          echo "  REAL ~/$rel (not linked; stow skipped it)"
        fi
      fi
    done < <(git -C "$ROOT" ls-files -- "$pkg")
  done
  echo "  $ok linked, $bad problems"
  return 0
}

if [[ "$CHECK" -eq 1 ]]; then
  verify
  exit 0
fi

# --adopt would pull these live files INTO the repo; clear them first. Without
# --adopt the generic conflict pass below backs up whatever is in the way.
if [[ "$ADOPT" -eq 1 ]]; then
  echo "==> Preparing conflicting real files (replace with symlinks)"
  # bin: drop real files that should come from the package
  if [[ -d bin/.local/bin ]]; then
    mkdir -p "$TARGET/.local/bin"
    for f in bin/.local/bin/*; do
      [[ -f "$f" ]] || continue
      base="$(basename "$f")"
      dest="$TARGET/.local/bin/$base"
      if [[ -e "$dest" && ! -L "$dest" ]]; then
        backup ".local/bin/$base"
      elif [[ -L "$dest" ]]; then
        # Replace foreign symlinks (e.g. AppImage direct link) with stow-managed ones.
        echo "  rm old symlink $dest -> $(readlink "$dest")"
        rm -f "$dest"
      fi
    done
  fi

  # bin desktop entries / icons
  if [[ -d bin/.local/share/applications ]]; then
    mkdir -p "$TARGET/.local/share/applications"
    for f in bin/.local/share/applications/*; do
      [[ -f "$f" ]] || continue
      base="$(basename "$f")"
      dest="$TARGET/.local/share/applications/$base"
      if [[ -L "$dest" ]]; then
        rm -f "$dest"
      elif [[ -e "$dest" ]]; then
        backup ".local/share/applications/$base"
      fi
    done
  fi
  if [[ -d bin/.local/share/icons ]]; then
    while IFS= read -r -d '' f; do
      rel="${f#bin/}"
      dest="$TARGET/$rel"
      mkdir -p "$(dirname "$dest")"
      if [[ -L "$dest" ]]; then
        rm -f "$dest"
      elif [[ -e "$dest" ]]; then
        backup "$rel"
      fi
    done < <(find bin/.local/share/icons -type f -print0)
  fi

  # entropy app settings
  if [[ -f entropy/.config/entropy/app_settings.json ]]; then
    dest="$TARGET/.config/entropy/app_settings.json"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
      backup .config/entropy/app_settings.json
    elif [[ -L "$dest" ]]; then
      rm -f "$dest"
    fi
  fi

  # x11: .Xresources
  if [[ -e "$TARGET/.Xresources" && ! -L "$TARGET/.Xresources" ]]; then
    backup .Xresources
  fi
fi

echo "==> Prefer clean directory symlinks when possible"
# Empty leftover dirs owned wrongly block dir-level links; fold is still valid.
mkdir -p gtk/.config/gtk-3.0
touch gtk/.config/gtk-3.0/bookmarks

# Parse `stow -n` conflicts; print one target path (relative to $TARGET) per line.
conflicts() {
  stow -n -v -t "$TARGET" "$1" 2>&1 | sed -nE \
    -e 's/.* over existing target (.*) since .*/\1/p' \
    -e 's/.*existing target is not owned by stow: (.*)/\1/p' \
    -e 's/.*existing target is neither a link nor a directory: (.*)/\1/p'
}

if [[ "$ADOPT" -eq 1 ]]; then
  echo "==> Stow --adopt (merge live configs into repo, then symlink)"
else
  echo "==> Stow (conflicting live files are moved to $BACKUP)"
fi
for pkg in "${packages[@]}"; do
  if [[ ! -d "$pkg" ]]; then
    echo "  skip missing package: $pkg"
    continue
  fi
  echo "  stow $pkg"
  if [[ "$ADOPT" -eq 1 ]]; then
    stow --adopt -v -t "$TARGET" "$pkg" 2>&1 \
      || stow -R -v -t "$TARGET" "$pkg" 2>&1 \
      || echo "  WARN: stow $pkg failed (left as-is)"
    continue
  fi
  # Two passes: moving a file aside can expose a conflict one level up.
  for _ in 1 2; do
    mapfile -t found < <(conflicts "$pkg")
    [[ ${#found[@]} -eq 0 ]] && break
    for rel in "${found[@]}"; do backup "$rel"; done
  done
  stow -R -v -t "$TARGET" "$pkg" 2>&1 || echo "  WARN: stow $pkg failed (left as-is)"
done

# mimeapps.list must be a regular file. GIO writes mimeapps.list.XXXX next to
# it; a relative Stow symlink makes Nautilus "Always use for this type" fail.
mime_src="$ROOT/misc/.config/mimeapps.list"
mime_dst="$TARGET/.config/mimeapps.list"
if [[ -f "$mime_src" ]]; then
  mkdir -p "$TARGET/.config"
  if [[ -L "$mime_dst" ]]; then
    real="$(readlink -f "$mime_dst")"
    echo "==> mimeapps.list: replace relative symlink with regular file"
    rm -f "$mime_dst"
    cp -a "$real" "$mime_dst"
    chmod 644 "$mime_dst"
  elif [[ ! -e "$mime_dst" ]]; then
    echo "==> mimeapps.list: install regular file"
    cp -a "$mime_src" "$mime_dst"
    chmod 644 "$mime_dst"
  fi
fi

verify
echo
if [[ "$ADOPT" -eq 1 ]]; then
  echo "Done. Review git status — --adopt may have updated package files from live configs."
elif [[ -d "$BACKUP" ]]; then
  echo "Done. Replaced live files are in $BACKUP"
else
  echo "Done."
fi
echo "Note: sddm is system-level (sddm/install.sh / pkexec), not stowed into \$HOME."