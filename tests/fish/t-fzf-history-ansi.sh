#!/usr/bin/env bash
# history --show-time glues set_color normal (\e[m) onto fzf field 3.
# Accepting that field must not put ESC in front of the recalled command,
# and a command line that already starts with the reset must not seed the
# next search. No TTY: fzf --filter plus the same fish strip as the widget.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
widget="$root/fish/.config/fish/conf.d/terminal-utils.fish"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if ! grep -F "string replace -ra '\\e\\[[0-9;]*m'" "$widget" >/dev/null; then
  echo "widget is missing the SGR strip" >&2
  exit 1
fi
# Query seed and accepted command each strip once.
count="$(grep -c -F "string replace -ra '\\e\\[[0-9;]*m'" "$widget")"
if [[ "$count" -ne 2 ]]; then
  echo "expected the SGR strip twice in the widget, found $count" >&2
  exit 1
fi

# Same bytes history --show-time emits when set_color works:
# colored timestamp, tab, epoch, tab, \e[m + command.
python3 - "$tmp/record.bin" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
ts = b"\x1b[90m2026-09-28 Mon 18:51:39"
epoch = b"1790610699"
cmd = b"\x1b[mwhich python3"
path.write_bytes(ts + b"\t" + epoch + b"\t" + cmd + b"\0")
PY

fzf_accept() {
  # $1 = extra fzf args (e.g. --ansi), output path $2
  # shellcheck disable=SC2086
  fzf --filter=which --read0 --print0 --delimiter="$(printf '\t')" \
    --accept-nth=3.. $1 <"$tmp/record.bin" >"$2"
}

fzf_accept --ansi "$tmp/ansi.bin"
python3 - "$tmp/ansi.bin" <<'PY'
import pathlib, sys
data = pathlib.Path(sys.argv[1]).read_bytes().rstrip(b"\0")
assert b"\x1b" not in data, data
assert data == b"which python3", data
PY

fzf_accept "" "$tmp/raw.bin"
python3 - "$tmp/raw.bin" <<'PY'
import pathlib, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
assert data.startswith(b"\x1b[mwhich python3"), data
PY

# Same strip the widget uses after accept, and on the search seed.
TERM=xterm-256color fish --no-config <<EOF
set -l raw (string split0 < $tmp/raw.bin)
set -l stripped (string replace -ra '\\e\\[[0-9;]*m' '' -- \$raw)
and set raw \$stripped
printf '%s\\0' \$raw > $tmp/stripped.bin

set -l query (printf "\\e[mwhich python3")
set -l stripped_query (string replace -ra '\\e\\[[0-9;]*m' '' -- \$query)
and set query \$stripped_query
printf '%s' \$query > $tmp/query.bin

set -l clean "which python3"
set -l stripped_clean (string replace -ra '\\e\\[[0-9;]*m' '' -- \$clean)
and set clean \$stripped_clean
printf '%s' \$clean > $tmp/clean.bin
EOF

python3 - "$tmp/stripped.bin" "$tmp/query.bin" "$tmp/clean.bin" <<'PY'
import pathlib, sys
stripped, query, clean = (pathlib.Path(p).read_bytes() for p in sys.argv[1:])
stripped = stripped.rstrip(b"\0")
assert stripped == b"which python3", stripped
assert b"\x1b" not in stripped
assert query == b"which python3", query
assert clean == b"which python3", clean
PY

echo "ok"
