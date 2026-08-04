#!/usr/bin/env bash
# Restow all dotfiles packages into $HOME (GNU Stow)
# Usage: ./restow.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${HOME}"
cd "$ROOT"

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
  waybar
  waypaper
  wofi
  x11
  xsettingsd
  yazi
  zen
)

echo "==> Preparing conflicting real files (replace with symlinks)"
# bin: drop real files that should come from the package
if [[ -d bin/.local/bin ]]; then
  mkdir -p "$TARGET/.local/bin"
  for f in bin/.local/bin/*; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    dest="$TARGET/.local/bin/$base"
    if [[ -e "$dest" && ! -L "$dest" ]]; then
      echo "  rm real file $dest (will symlink from package)"
      rm -f "$dest"
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
    if [[ -e "$dest" || -L "$dest" ]]; then
      echo "  rm $dest (will symlink from package)"
      rm -f "$dest"
    fi
  done
fi
if [[ -d bin/.local/share/icons ]]; then
  while IFS= read -r -d '' f; do
    rel="${f#bin/}"
    dest="$TARGET/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" || -L "$dest" ]]; then
      echo "  rm $dest (will symlink from package)"
      rm -f "$dest"
    fi
  done < <(find bin/.local/share/icons -type f -print0)
fi

# entropy app settings
if [[ -f entropy/.config/entropy/app_settings.json ]]; then
  dest="$TARGET/.config/entropy/app_settings.json"
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "  rm $dest (will symlink from package)"
    rm -f "$dest"
  fi
fi

# x11: .Xresources
if [[ -e "$TARGET/.Xresources" && ! -L "$TARGET/.Xresources" ]]; then
  echo "  rm real file $TARGET/.Xresources"
  rm -f "$TARGET/.Xresources"
fi

echo "==> Prefer clean directory symlinks when possible"
# Empty leftover dirs owned wrongly block dir-level links; fold is still valid.
mkdir -p gtk/.config/gtk-3.0
touch gtk/.config/gtk-3.0/bookmarks

echo "==> Stow --adopt (merge live configs into repo, then symlink)"
for pkg in "${packages[@]}"; do
  if [[ ! -d "$pkg" ]]; then
    echo "  skip missing package: $pkg"
    continue
  fi
  echo "  stow $pkg"
  if ! stow --adopt -v -t "$TARGET" "$pkg" 2>&1; then
    if ! stow -R -v -t "$TARGET" "$pkg" 2>&1; then
      echo "  WARN: stow $pkg failed (left as-is)"
    fi
  fi
done

ok_link() {
  local p="$1"
  if [[ -L "$TARGET/$p" ]]; then
    echo "  OK   $p -> $(readlink "$TARGET/$p")"
  elif [[ -d "$TARGET/$p" ]]; then
    # Folded stow: directory exists, files inside should be symlinks into the repo
    local bad=0
    while IFS= read -r -d '' f; do
      if [[ ! -L "$f" ]]; then
        # allow empty bookmarks etc only if tracked in package later
        bad=1
      fi
    done < <(find "$TARGET/$p" -mindepth 1 -maxdepth 2 \( -type f -o -type l \) -print0 2>/dev/null)
    if [[ "$bad" -eq 0 ]]; then
      echo "  OK   $p (folded; contents -> dotfiles)"
    else
      echo "  WARN $p has non-symlink files"
      find "$TARGET/$p" -mindepth 1 -maxdepth 2 ! -type l -printf '       %p\n' 2>/dev/null | head -10
    fi
  else
    echo "  MISS $p"
  fi
}

echo "==> Verify"
for p in \
  .config/hypr \
  .config/quickshell \
  .config/entropy \
  .config/matugen \
  .config/waypaper \
  .config/kitty \
  .config/fish \
  .config/waybar \
  .config/wofi \
  .config/vibepanel \
  .config/nwg-look \
  .config/xsettingsd \
  .config/fastfetch \
  .config/gtk-3.0 \
  .config/gtk-4.0 \
  .config/kanata \
  .config/nvim \
  .config/yazi \
  .config/tmux \
  .config/theme \
  .config/obs-studio/global.ini \
  .config/gromit-mpx/gromit-mpx.cfg \
  .config/starship.toml \
  .tmux.conf \
  .local/bin/entropy \
  .local/bin/obs-record-toggle \
  .Xresources
do
  ok_link "$p"
done

echo
echo "Done. Review git status — --adopt may have updated package files from live configs."
echo "Note: sddm is system-level (sddm/install.sh / pkexec), not stowed into \$HOME."
echo "Note: Hyprland .conf is deprecated in 0.57 — migrate to hyprland.lua before upgrading."