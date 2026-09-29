#!/usr/bin/env bash
# Login VPN must connect to the lowest-ping location.
# A Russian location is never eligible when any other location has a ping:
# if the fastest server is in Russia, the choice is the fastest server that
# is not. "Second place" is not enough — Moscow and Saint Petersburg can
# occupy both of the top slots, and a Russian exit is the failure mode.
#
# Russian means the CLI region (text before the first " - ") is "Russia",
# compared case-insensitively. "Best Location - …" is the CLI alias for
# Windscribe's own best node and is not a candidate.
#
# Pings are positive integers in milliseconds. Zero, blank, and non-numeric
# values do not rank. Comparison is numeric. Equal pings keep the earlier
# location-list order. The printed connect target is the city name, spelled
# as in the locations list (windscribe-cli connect "CityName").
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pick="$root/hypr/.config/hypr/scripts/vpn-pick-location"
autostart="$root/hypr/.config/hypr/scripts/vpn-autostart.sh"
fail=0

say() { printf '%s\n' "$*" >&2; }

expect_eq() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    say "ok  $name"
  else
    say "FAIL $name"
    say "  got:  $(printf '%q' "$got")"
    say "  want: $(printf '%q' "$want")"
    fail=1
  fi
}

expect_status() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" -eq "$want" ]]; then
    say "ok  $name"
  else
    say "FAIL $name"
    say "  exit: $got  want: $want"
    fail=1
  fi
}

LOCATIONS="$(cat <<'EOF'
Best Location - Hermitage (10 Gbps)
Russia - Fake St Petersburg - Hermitage (10 Gbps)
Russia - Moscow - Goodbye Lenin (10 Gbps)
Latvia - Riga - Saeima (10 Gbps)
Sweden - Stockholm - Meatballs (10 Gbps)
Finland - Helsinki - Sauna (10 Gbps)
EOF
)"

write_locations() {
  local dest="$1"
  printf '%s\n' "$LOCATIONS" >"$dest"
}

run_pick() {
  local locations="$1" pings="$2"
  "$pick" --locations "$locations" --pings "$pings"
}

if [[ ! -x "$pick" ]]; then
  say "FAIL vpn-pick-location is missing or not executable ($pick)"
  fail=1
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  write_locations "$tmp/locations"

  # Fastest overall is not Russian.
  cat >"$tmp/pings" <<'EOF'
Fake St Petersburg|40|1
Moscow|50|1
Riga|10|1
Stockholm|30|1
Helsinki|20|1
EOF
  got="$(run_pick "$tmp/locations" "$tmp/pings" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "fastest non-russian exits 0" "$status" 0
  expect_eq "fastest non-russian is Riga" "$got" "Riga"

  # Fastest is Russian; the next ping is not. Gbps labels must not count as ping.
  cat >"$tmp/pings" <<'EOF'
Fake St Petersburg|24|1
Moscow|86|1
Riga|29|1
Stockholm|33|1
Helsinki|36|1
EOF
  got="$(run_pick "$tmp/locations" "$tmp/pings" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "skip one russian exits 0" "$status" 0
  expect_eq "skip one russian picks Riga not Hermitage" "$got" "Riga"

  # Both of the fastest servers are Russian. Second place is still a ban.
  cat >"$tmp/pings" <<'EOF'
Fake St Petersburg|10|1
Moscow|12|1
Riga|29|1
Stockholm|33|1
Helsinki|36|1
EOF
  got="$(run_pick "$tmp/locations" "$tmp/pings" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "two russian leaders exit 0" "$status" 0
  expect_eq "two russian leaders still pick Riga" "$got" "Riga"

  # Lexicographic order would rank "100" ahead of "29" and "9".
  cat >"$tmp/pings" <<'EOF'
Moscow|9|1
Helsinki|100|1
Riga|29|1
EOF
  got="$(run_pick "$tmp/locations" "$tmp/pings" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "numeric ping exits 0" "$status" 0
  expect_eq "numeric ping picks Riga over Helsinki 100" "$got" "Riga"

  # No ping → not a candidate. Ping key case does not change the city spelling.
  cat >"$tmp/pings" <<'EOF'
fake st petersburg|24|1
stockholm|33|1
riga|
helsinki|0|1
EOF
  got="$(run_pick "$tmp/locations" "$tmp/pings" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "missing ping exits 0" "$status" 0
  expect_eq "missing and zero pings leave Stockholm" "$got" "Stockholm"

  # An unfamiliar Russian city is still Russian because the region says so.
  cat >"$tmp/locations-kazan" <<'EOF'
Best Location - Hermitage (10 Gbps)
Russia - Kazan - Kul Sharif (10 Gbps)
Latvia - Riga - Saeima (10 Gbps)
EOF
  cat >"$tmp/pings-kazan" <<'EOF'
Kazan|5|1
Riga|40|1
EOF
  got="$(run_pick "$tmp/locations-kazan" "$tmp/pings-kazan" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "unknown russian city exits 0" "$status" 0
  expect_eq "region Russia excludes Kazan" "$got" "Riga"

  # Tie: keep locations-file order among equal positive pings.
  cat >"$tmp/pings" <<'EOF'
Riga|40|1
Stockholm|40|1
Helsinki|41|1
EOF
  got="$(run_pick "$tmp/locations" "$tmp/pings" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "ping tie exits 0" "$status" 0
  expect_eq "ping tie keeps earlier city Riga" "$got" "Riga"

  # Only Russian rows, or no usable ping: refuse rather than guessing "best".
  cat >"$tmp/pings" <<'EOF'
Fake St Petersburg|10|1
Moscow|12|1
EOF
  got="$(run_pick "$tmp/locations" "$tmp/pings" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "only russian exits 1" "$status" 1
  expect_eq "only russian prints nothing" "$got" ""

  : >"$tmp/empty-pings"
  got="$(run_pick "$tmp/locations" "$tmp/empty-pings" 2>"$tmp/err")" && status=0 || status=$?
  expect_status "no pings exits 1" "$status" 1
  expect_eq "no pings prints nothing" "$got" ""
fi

# Autostart must use the same choice. It must not ask the CLI for "best":
# windscribe-cli's best location is Hermitage (Russia - Fake St Petersburg).
iso="$(mktemp -d)"
mkdir -p "$iso/bin" "$iso/run" "$iso/cache" "$iso/config"
cat >"$iso/bin/notify-send" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$iso/bin/windscribe-cli" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${VPN_FAKE_LOG:?}"
if [ "$1" = "status" ]; then
  printf '%s\n' "${VPN_FAKE_STATUS:-Connect state: Disconnected}"
fi
exit 0
EOF
chmod +x "$iso/bin/notify-send" "$iso/bin/windscribe-cli"
printf '%s\n' "$LOCATIONS" >"$iso/locations"
cat >"$iso/pings" <<'EOF'
Fake St Petersburg|24|1
Moscow|86|1
Riga|29|1
Stockholm|33|1
Helsinki|36|1
EOF

run_autostart() {
  local log="$1"
  : >"$log"
  PATH="$iso/bin:/usr/bin" \
    WINDSCRIBE_CLI="$iso/bin/windscribe-cli" \
    VPN_FAKE_LOG="$log" \
    VPN_FAKE_STATUS="${2:-Connect state: Disconnected}" \
    VPN_LOCATIONS_FILE="$iso/locations" \
    VPN_PINGS_FILE="$iso/pings" \
    XDG_RUNTIME_DIR="$iso/run" \
    XDG_CACHE_HOME="$iso/cache" \
    XDG_CONFIG_HOME="$iso/config" \
    HOME="$iso" \
    "$autostart"
  local i
  for i in $(seq 1 50); do
    if [[ -s "$log" ]] && grep -q '^connect ' "$log"; then
      break
    fi
    # Already-connected returns before any connect line; status is enough.
    if [[ "${2:-}" == *"Connected"* ]] && grep -q '^status$' "$log"; then
      break
    fi
    sleep 0.05
  done
}

run_autostart "$iso/log-pick"
connect_lines="$(grep '^connect ' "$iso/log-pick" || true)"
expect_eq "autostart connects to Riga" "$connect_lines" "connect Riga"
if grep -q 'connect best' "$iso/log-pick"; then
  say "FAIL autostart issued connect best"
  fail=1
else
  say "ok  autostart did not issue connect best"
fi

run_autostart "$iso/log-up" "Connect state: Connected"
if grep -q '^connect ' "$iso/log-up"; then
  say "FAIL autostart reconnected while already up"
  say "  $(tr '\n' ' ' <"$iso/log-up")"
  fail=1
else
  say "ok  autostart leaves an existing session alone"
fi

# Nothing eligible: do not fall back to the CLI's Russian "best".
cat >"$iso/pings" <<'EOF'
Fake St Petersburg|10|1
Moscow|12|1
EOF
run_autostart "$iso/log-refuse"
if grep -q '^connect ' "$iso/log-refuse"; then
  say "FAIL autostart connected when every ping was Russian"
  say "  $(tr '\n' ' ' <"$iso/log-refuse")"
  fail=1
else
  say "ok  autostart refuses when only Russian pings exist"
fi

# The panel's "best" action is the same CLI token. It must connect the
# picked city and pass the protocol the helper already uses (wireguard).
cat >"$iso/pings" <<'EOF'
Fake St Petersburg|24|1
Moscow|86|1
Riga|29|1
Stockholm|33|1
Helsinki|36|1
EOF
: >"$iso/log-panel"
PATH="$iso/bin:/usr/bin" \
  WINDSCRIBE_CLI="$iso/bin/windscribe-cli" \
  VPN_FAKE_LOG="$iso/log-panel" \
  VPN_LOCATIONS_FILE="$iso/locations" \
  VPN_PINGS_FILE="$iso/pings" \
  XDG_RUNTIME_DIR="$iso/run" \
  XDG_CACHE_HOME="$iso/cache" \
  XDG_CONFIG_HOME="$iso/config" \
  HOME="$iso" \
  "$root/hypr/.config/hypr/scripts/qs-vpn.sh" best >/dev/null 2>&1 || true
panel_connect="$(grep '^connect ' "$iso/log-panel" || true)"
expect_eq "panel best connects to Riga over wireguard" "$panel_connect" "connect Riga wireguard"
if grep -q 'connect best' "$iso/log-panel"; then
  say "FAIL panel best issued connect best"
  fail=1
else
  say "ok  panel best did not issue connect best"
fi

rm -rf "$iso"
if [[ "$fail" -ne 0 ]]; then
  say "vpn location tests failed"
  exit 1
fi
say "vpn location tests passed"
