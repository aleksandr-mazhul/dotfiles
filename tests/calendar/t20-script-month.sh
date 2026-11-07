#!/usr/bin/env bash
# qs-calendar.sh `month` / `sync` / `calendars` write an on-disk cache and must
# never delete khal's sqlite cache. Runs in a temp HOME with fake khal/vdirsyncer.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/hypr/.config/hypr/scripts/qs-calendar.sh"
fail=0
n=0

say() { printf '%s\n' "$*" >&2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

expect_eq() {
  local name="$1" got="$2" want="$3"
  n=$((n + 1))
  if [[ "$got" == "$want" ]]; then
    say "ok  $name"
  else
    say "FAIL $name"
    say "  got:  $got"
    say "  want: $want"
    fail=1
  fi
}

mkdir -p "$tmp/home" "$tmp/bin"
export HOME="$tmp/home"
unset XDG_CACHE_HOME
export QS_CAL_CACHE="$tmp/cache"
export FAKE_LOG="$tmp/khal.log"
export FAKE_OUT="$tmp/khal.out"
export QS_CAL_CALMAP_JSON='{"Уник":{"path":"/x","color":"#ff0000","readonly":true,"label":"Уник","default":false},"Дом":{"path":"/y","color":"#00ff00","readonly":false,"label":"Дом","default":true}}'

cat > "$tmp/bin/khal" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_LOG"
[[ "${1:-}" == list ]] && cat "$FAKE_OUT"
exit 0
FAKE
cat > "$tmp/bin/vdirsyncer" <<'FAKE'
#!/usr/bin/env bash
# discover gets `yes` on stdin; never drain it, or each sync waits out the timeout.
exit 0
FAKE
chmod +x "$tmp/bin/khal" "$tmp/bin/vdirsyncer"
export PATH="$tmp/bin:$PATH"
export KHAL="$tmp/bin/khal" VDIRSYNCER="$tmp/bin/vdirsyncer"

cat > "$FAKE_OUT" <<'EOF2'
[{"title":"A","start-date":"2026-11-07","start-time":"08:15","end-time":"09:35","location":"148","calendar":"Дом","uid":"u1"}, {"title":"A","start-date":"2026-11-07","start-time":"08:15","end-time":"09:35","location":"148","calendar":"Уник","uid":"u1"}]
[{"title":"B","start-date":"2026-11-09","start-time":"10:00","end-time":"11:00","location":"","calendar":"Дом","uid":"u2"}]
EOF2

run() { bash "$script" "$@"; }

# a. shape + requested range
set +e
out="$(run month 2026-11)"
rc=$?
set -e
expect_eq "month exit 0" "$rc" "0"
expect_eq "month is one line" "$(printf '%s\n' "$out" | wc -l)" "1"
shape="$(printf '%s' "$out" | python3 -c 'import json,sys
o=json.load(sys.stdin)
print(o.get("month"), isinstance(o.get("fetchedAt"), int), isinstance(o.get("events"), list), len(o.get("events", [])))' 2>&1 || true)"
expect_eq "month shape" "$shape" "2026-11 True True 2"
expect_eq "khal range" "$(grep -c '^list 2026-11-01 2026-11-30' "$FAKE_LOG" || true)" "1"

# b. dedupe: readonly calendar wins
cal_u1="$(printf '%s' "$out" | python3 -c 'import json,sys
print([e["calendar"] for e in json.load(sys.stdin)["events"] if e["uid"]=="u1"])')"
expect_eq "dedupe readonly wins" "$cal_u1" "['Уник']"

# c. file == stdout, no tmp leftovers
f="$QS_CAL_CACHE/months/2026-11.json"
[[ -f "$f" ]] && have=yes || have=no
expect_eq "month file exists" "$have" "yes"
expect_eq "file equals stdout" "$(cat "$f")" "$out"
expect_eq "no tmp leftovers" "$(find "$QS_CAL_CACHE" -name '*.tmp.*' | wc -l)" "0"

# d. identical data: no rewrite; changed data: rewrite
before="$(stat -c '%i %Y' "$f")"
sleep 1.1
out2="$(run month 2026-11)"
expect_eq "unchanged: file untouched" "$(stat -c '%i %Y' "$f")" "$before"
expect_eq "unchanged: stdout still printed" "$out2" "$out"
sed -i 's/"title":"B"/"title":"B2"/' "$FAKE_OUT"
sleep 1.1
out3="$(run month 2026-11)"
[[ "$(stat -c '%i %Y' "$f")" != "$before" ]] && changed=yes || changed=no
expect_eq "changed: file rewritten" "$changed" "yes"
expect_eq "changed: file equals stdout" "$(cat "$f")" "$out3"
expect_eq "changed: stdout has new title" "$(printf '%s' "$out3" | grep -c B2 || true)" "1"

# e. bad arguments
for bad in 2026-13 foo 2026-00 ""; do
  set +e
  run month "$bad" >/dev/null 2>&1
  rc=$?
  set -e
  expect_eq "month '$bad' exits 2" "$rc" "2"
done

# f. sync warms prev/cur/next, writes calendars.json, keeps khal.db
mkdir -p "$HOME/.cache/khal"
echo db > "$HOME/.cache/khal/khal.db"
rm -rf "$QS_CAL_CACHE"
set +e
sync_out="$(run sync 2>/dev/null)"
rc=$?
set -e
expect_eq "sync exit 0" "$rc" "0"
expect_eq "sync prints ok" "$sync_out" "ok"
cur="$(date +%Y-%m)"
prev="$(date -d "$(date +%Y-%m-01) -1 month" +%Y-%m)"
next="$(date -d "$(date +%Y-%m-01) +1 month" +%Y-%m)"
for m in "$prev" "$cur" "$next"; do
  [[ -f "$QS_CAL_CACHE/months/$m.json" ]] && have=yes || have=no
  expect_eq "sync wrote $m" "$have" "yes"
done
expect_eq "sync wrote only 3 months" "$(find "$QS_CAL_CACHE/months" -name '*.json' | wc -l)" "3"
expect_eq "calendars.json == calmap" "$(cat "$QS_CAL_CACHE/calendars.json")" "$QS_CAL_CALMAP_JSON"
[[ -f "$HOME/.cache/khal/khal.db" ]] && have=yes || have=no
expect_eq "khal.db survives sync" "$have" "yes"

# calendars command prints and caches
rm -f "$QS_CAL_CACHE/calendars.json"
expect_eq "calendars prints calmap" "$(run calendars)" "$QS_CAL_CALMAP_JSON"
expect_eq "calendars cached" "$(cat "$QS_CAL_CACHE/calendars.json")" "$QS_CAL_CALMAP_JSON"

# A failing khal during sync must keep the old cache, not blank it to [].
cur="$(date +%Y-%m)"
before="$(cat "$QS_CAL_CACHE/months/$cur.json")"
cp "$tmp/bin/khal" "$tmp/khal.ok"
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/khal"
run sync >/dev/null 2>&1 || true
expect_eq "khal failure keeps cached month" "$(cat "$QS_CAL_CACHE/months/$cur.json")" "$before"
cp "$tmp/khal.ok" "$tmp/bin/khal"

# g. invalidate_khal gone
expect_eq "no invalidate_khal in script" "$(grep -c invalidate_khal "$script" || true)" "0"

say "$n assertions"
exit "$fail"
