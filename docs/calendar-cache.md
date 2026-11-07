# Calendar panel: stale-while-revalidate cache

The Quickshell calendar (`quickshell/.config/quickshell/rice/Calendar.qml`) shows
events instantly from a cache, then revalidates quietly in the background and
patches only what changed. Same idea as TanStack Query: cached data first,
background fetch, structural diff, optimistic mutations.

## Why it was slow

`qs-calendar.sh` called `invalidate_khal` (deletes `~/.cache/khal/khal.db`) after
every `sync`, `watch` change, `add`, `edit` and `delete`. Sync runs on every panel
open, every 20 s while open and every 15 min from the systemd timer, so almost
every `khal list` re-indexed ~1300 `.ics` files: ~1.9 s instead of ~0.2 s.
khal's own `update_db()` already compares mtime etags per item, so the deletion
was never needed. It is removed.

The QML also replaced `root.events` wholesale, so `ListView` rebuilt every row on
each refresh.

## Data flow

```
open panel
  ├─ 1. read ~/.cache/qs-calendar/months/<cur>.json + calendars.json  (sync, ~0 ms)
  ├─ 2. qs-calendar.sh month <cur>        → khal, no network (~0.4 s) → diff
  ├─ 3. qs-calendar.sh sync               → vdirsyncer (~4 s), then warms prev/cur/next
  │       └─ qs-calendar.sh month <cur>   → diff
  ├─ 4. prefetch month <prev>, <next>     (low priority, after 2)
  └─ watch 20: on "changed" → month <cur> → diff
```

↻ in the header spins while any fetch or sync runs. Data never disappears
while revalidating.

## Cache owner: the script

Only `qs-calendar.sh` writes cache files. QML reads them.

Directory: `${QS_CAL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/qs-calendar}`

| File | Written by | Shape |
|---|---|---|
| `months/YYYY-MM.json` | `month YYYY-MM`, `sync` (warms prev/cur/next) | `{"month":"2026-11","fetchedAt":1762526400,"events":[<row>, ...]}` |
| `calendars.json` | `calendars`, `sync` | same object `calendars` prints today |

`<row>` is exactly what `events` prints today (khal `--json` fields `title`,
`start-date`, `start-time`, `end-time`, `location`, `calendar`, `uid`), after the
existing duplicate-UID removal (read-only calendar wins). Rows keep khal's
order (by day, then time).

Writes are atomic: write `<file>.tmp.$$`, then `mv`. If the `events` array is
byte-identical to what's on disk, the file is **not** rewritten (mtime stays), so
nothing downstream sees a change.

`month` prints the same JSON object to stdout on one line (including when the
file was not rewritten), exit 0. Bad argument → usage, exit 2.

### Script changes

- New command `month YYYY-MM` (above).
- `sync`: after `sync_now`, runs `month` for prev/cur/next month (relative to
  today) and refreshes `calendars.json`. The systemd timer therefore keeps the
  cache warm while the panel is closed.
- `invalidate_khal` and all its calls are removed.
- `days` and `events` stay for compatibility; QML no longer calls them.
- Test hooks (env): `KHAL`, `VDIRSYNCER` (already exist), `QS_CAL_CACHE`, and
  `QS_CAL_CALMAP_JSON` — when set, `calmap` prints it instead of running Python.

## Pure logic: `rice/calendarCache.js`

`.pragma library`, no Qt imports, so node can test it (the test strips the
`.pragma` line and evaluates the rest).

```js
eventKey(ev)                    // `${uid}|${start-date}|${start-time}`
monthKey(year, month0)          // (2026, 10) -> "2026-11"
neighborMonths(key)             // "2026-01" -> ["2025-12", "2026-02"]
parseMonth(text)                // tolerant: JSON → {month, fetchedAt, events} | null
eventsForDay(events, isoDate)   // rows whose start-date === isoDate, original order
dayDots(events)                 // {"7": ["Рабочий","Домашний"]} unique cals, first-seen order
dotsEqual(a, b)                 // deep equality of two dayDots maps
eventChanged(a, b)              // true if any rendered field differs
diffList(oldItems, newItems)    // ops that turn old into new, keyed by eventKey
applyOps(array, ops)            // reference applier (tests + documents ListModel semantics)
applyOptimistic(events, m)      // m: {kind:"add"|"edit"|"delete", event?, uid?} → new array
reconcilePending(fresh, pending)// fresh server rows + in-flight mutations → rows to show
```

### `diffList` contract

Ops, applied in order with `ListModel` semantics:

```js
{ op: "remove", index }
{ op: "insert", index, item }
{ op: "move",   from, to }      // ListModel.move(from, to, 1)
{ op: "set",    index, item }
```

- Same keys, nothing changed → `[]` (no repaint).
- One new event → exactly one `insert`.
- One deleted event → exactly one `remove`.
- Title/time/location/calendar change on an existing key → exactly one `set`.
- For any inputs: `applyOps(old, diffList(old, new))` deep-equals `new`.

### Optimistic mutations

Pending mutation: `{id, kind, event?, uid?}`. Optimistic rows carry
`pending: true`; an added row gets `uid: "optimistic-<id>"` until revalidation
returns the real one.

The cache only ever holds server rows. What is rendered is always
`reconcilePending(cachedRows, pendingMutations)`, so there is no snapshot to
restore: on failure the mutation is dropped from the pending list, the view is
recomputed, and status shows "Failed".

`reconcilePending` lays mutations over the fresh rows in submit order. An `add`
whose event already came back from khal (same title, start-date and start-time
on a non-pending row) is skipped, because `add` writes the `.ics` before it syncs
and a revalidation can land in between. An `edit` whose uid is gone from fresh
was deleted elsewhere, so the server wins.

## QML integration (`Calendar.qml`)

- `monthCache`: JS map `{ "YYYY-MM": {fetchedAt, events} }`, seeded from disk via
  `FileView` with `blockLoading: true` so the first frame is already filled.
- One fetch queue (single `Process`, serial: khal's sqlite is not shared-writer
  safe). Visible month jumps the queue; prefetch goes last; duplicates collapse.
- `eventsModel: ListModel` with flat roles (`key, title, startDate, startTime,
  endTime, location, calendar, uid, pending`), patched with `diffList` ops.
  `ListView` gets `add`/`remove`/`displaced` transitions (fade ~180 ms).
- Selecting a day reads from `monthCache`: no process.
- Dots: `eventDays` is reassigned only when `!dotsEqual(old, new)`. Each dot
  fades in/out (`Behavior on opacity`).
- ↻ spins (`RotationAnimation`, loops) while `fetching || syncProc.running`.
- `colorsProc` is replaced by reading `calendars.json` first, then the live call.

## Tests

`tests/calendar/run.sh` runs:

- `t10-cache-logic.sh` → `node tests/calendar/cache-logic.test.mjs` (pure JS).
- `t20-script-month.sh` → fake `khal`/`vdirsyncer` on `PATH`, temp
  `QS_CAL_CACHE`/`HOME`: `month` output shape, dedup, atomic write, no rewrite on
  identical data, `sync` warms prev/cur/next, `khal.db` survives sync, no
  `invalidate_khal` left in the script.
