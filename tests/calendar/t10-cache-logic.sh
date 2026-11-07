#!/usr/bin/env bash
# Pure-JS cache logic tests (rice/calendarCache.js).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
node --test tests/calendar/cache-logic.test.mjs
