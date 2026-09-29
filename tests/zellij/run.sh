#!/usr/bin/env bash
# Run every zellij migration test. Exit non-zero if any test file fails.
#   tests/zellij/run.sh            all tests
#   tests/zellij/run.sh t10 t30    only files whose name starts with these
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

failed=()
for t in t*.sh; do
  if [ "$#" -gt 0 ]; then
    match=0
    for p in "$@"; do [[ "$t" == "$p"* ]] && match=1; done
    [ "$match" -eq 1 ] || continue
  fi
  printf '== %s\n' "$t"
  bash "$t" || failed+=("$t")
done

if [ "${#failed[@]}" -eq 0 ]; then
  echo "ALL GREEN"
else
  echo "FAILED: ${failed[*]}"
  exit 1
fi
