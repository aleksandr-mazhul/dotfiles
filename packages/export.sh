#!/usr/bin/env bash
# Export current explicit packages into packages/{repo,aur}.txt
# Usage: ./packages/export.sh
#
# Names already kept in hw-*.txt (hardware-specific), ignore.txt (installed but
# deliberately unlisted) or required.txt (runtime
# deps of the repo's scripts) are left out of repo.txt/aur.txt, so a refresh
# never folds this machine's drivers back into the generic lists.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/packages"
mkdir -p "$DIR"

exclude="$(mktemp)"
trap 'rm -f "$exclude"' EXIT
cat "$DIR"/hw-*.txt "$DIR/required.txt" "$DIR/ignore.txt" 2>/dev/null \
  | sed -e 's/#.*//' -e 's/[[:space:]]//g' | grep -v '^$' | sort -u >"$exclude" || true

# -e: explicit only (deps that went foreign, e.g. dropped from the repos, stay out)
pacman -Qqen | sort | comm -23 - "$exclude" >"$DIR/repo.txt"
pacman -Qqem | sort | grep -v -- '-debug$' | comm -23 - "$exclude" >"$DIR/aur.txt"

echo "Wrote $(wc -l <"$DIR/repo.txt") official + $(wc -l <"$DIR/aur.txt") AUR packages"
echo "  $DIR/repo.txt"
echo "  $DIR/aur.txt"
echo "Refresh curated rice-*.txt, hw-*.txt and required.txt by hand."
