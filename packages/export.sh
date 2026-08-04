#!/usr/bin/env bash
# Export current explicit packages into packages/{repo,aur}.txt
# Usage: ./packages/export.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/packages"
mkdir -p "$DIR"

comm -23 <(pacman -Qqe | sort) <(pacman -Qqm | sort) >"$DIR/repo.txt"
pacman -Qqm | sort | grep -v -- '-debug$' >"$DIR/aur.txt"

echo "Wrote $(wc -l <"$DIR/repo.txt") official + $(wc -l <"$DIR/aur.txt") AUR packages"
echo "  $DIR/repo.txt"
echo "  $DIR/aur.txt"
echo "Refresh curated rice-*.txt by hand if you added new rice tools."
