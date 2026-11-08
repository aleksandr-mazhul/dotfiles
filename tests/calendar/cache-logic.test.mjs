import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const src = readFileSync(
  path.join(here, "../../quickshell/.config/quickshell/rice/calendarCache.js"), "utf8");
const lines = src.split("\n");
assert.equal(lines[0].trim(), ".pragma library");
const ctx = {};
vm.runInNewContext(lines.slice(1).join("\n"), ctx);
const clone = (x) => JSON.parse(JSON.stringify(x));
// Results are JSON round-tripped so deepStrictEqual does not trip over
// cross-realm Array/Object prototypes from the vm context.
const C = {};
for (const k of Object.keys(ctx)) {
  C[k] = (...args) => {
    const r = ctx[k](...args);
    return r === undefined ? r : clone(r);
  };
}

const ev = (uid, o = {}) => Object.assign({
  title: "T" + uid, "start-date": "2026-11-07", "start-time": "08:15",
  "end-time": "09:35", location: "148", calendar: "Уник", uid: uid + "@x",
}, o);

test("eventKey format", () => {
  assert.equal(C.eventKey(ev("abc")), "abc@x|2026-11-07|08:15");
  assert.equal(C.eventKey(ev("a", { "start-time": "" })), "a@x|2026-11-07|");
});

test("monthKey", () => {
  assert.equal(C.monthKey(2026, 10), "2026-11");
  assert.equal(C.monthKey(2026, 0), "2026-01");
  assert.equal(C.monthKey(2026, 11), "2026-12");
});

test("neighborMonths", () => {
  assert.deepEqual(C.neighborMonths("2026-01"), ["2025-12", "2026-02"]);
  assert.deepEqual(C.neighborMonths("2026-12"), ["2026-11", "2027-01"]);
  assert.deepEqual(C.neighborMonths("2026-06"), ["2026-05", "2026-07"]);
});

test("parseMonth valid", () => {
  const o = { month: "2026-11", fetchedAt: 5, events: [ev("a")] };
  assert.deepEqual(C.parseMonth(JSON.stringify(o)), o);
});

test("parseMonth garbage and bad shape", () => {
  assert.equal(C.parseMonth("garbage"), null);
  assert.equal(C.parseMonth(""), null);
  assert.equal(C.parseMonth(undefined), null);
  assert.equal(C.parseMonth('{"month":"2026-11","events":{}}'), null);
  assert.equal(C.parseMonth('{"month":"2026-11"}'), null);
});

test("parseMonth tolerates leading/trailing noise", () => {
  const o = { month: "2026-11", fetchedAt: 5, events: [ev("a")] };
  const r = C.parseMonth("warn: x\n" + JSON.stringify(o) + "\n\n");
  assert.deepEqual(r, o);
});

test("eventsForDay keeps order", () => {
  const list = [ev("1"), ev("2", { "start-date": "2026-11-08" }), ev("3"), ev("0")];
  const r = C.eventsForDay(list, "2026-11-07");
  assert.deepEqual(r.map((e) => e.uid), ["1@x", "3@x", "0@x"]);
  assert.deepEqual(C.eventsForDay(list, "2026-01-01"), []);
});

test("dayDots", () => {
  const list = [
    ev("1", { "start-date": "2026-11-07", calendar: "Рабочий" }),
    ev("2", { "start-date": "2026-11-07", calendar: "Домашний" }),
    ev("3", { "start-date": "2026-11-07", calendar: "Рабочий" }),
    ev("4", { "start-date": "2026-11-07", calendar: "" }),
    ev("5", { "start-date": "2026-11-21", calendar: "Уник" }),
    ev("6", { "start-date": "2026-11-09" }),
  ];
  delete list[5].calendar;
  assert.deepEqual(C.dayDots(list), { "7": ["Рабочий", "Домашний"], "21": ["Уник"] });
  assert.deepEqual(C.dayDots([]), {});
});

test("dotsEqual", () => {
  assert.equal(C.dotsEqual({}, {}), true);
  assert.equal(C.dotsEqual({ "7": ["a", "b"] }, { "7": ["a", "b"] }), true);
  assert.equal(C.dotsEqual({ "7": ["a", "b"] }, { "7": ["b", "a"] }), false);
  assert.equal(C.dotsEqual({ "7": ["a"] }, { "7": ["a", "b"] }), false);
  assert.equal(C.dotsEqual({ "7": ["a"] }, { "8": ["a"] }), false);
  assert.equal(C.dotsEqual({ "7": ["a"] }, {}), false);
  assert.equal(C.dotsEqual({ "7": ["a"] }, { "7": ["a"], "8": ["a"] }), false);
});

test("eventChanged per field", () => {
  const a = ev("1");
  assert.equal(C.eventChanged(a, Object.assign({}, a)), false);
  for (const [f, v] of [["title", "X"], ["start-time", "10:00"], ["end-time", "11:00"],
    ["location", "Z"], ["calendar", "Other"], ["pending", true]]) {
    assert.equal(C.eventChanged(a, Object.assign({}, a, { [f]: v })), true, f);
  }
  // pending absent vs false is not a change
  assert.equal(C.eventChanged(a, Object.assign({}, a, { pending: false })), false);
});

test("diffList identical -> []", () => {
  const l = [ev("1"), ev("2")];
  assert.deepEqual(C.diffList(l, clone(l)), []);
  assert.deepEqual(C.diffList([], []), []);
});

test("diffList one insert", () => {
  const o = [ev("1"), ev("3")], n = [ev("1"), ev("2"), ev("3")];
  const ops = C.diffList(o, n);
  assert.equal(ops.length, 1);
  assert.deepEqual(ops[0], { op: "insert", index: 1, item: n[1] });
});

test("diffList one remove", () => {
  const o = [ev("1"), ev("2"), ev("3")], n = [ev("1"), ev("3")];
  const ops = C.diffList(o, n);
  assert.deepEqual(ops, [{ op: "remove", index: 1 }]);
});

test("diffList one field change -> one set", () => {
  const o = [ev("1"), ev("2")], n = clone(o);
  n[1].title = "changed";
  const ops = C.diffList(o, n);
  assert.deepEqual(ops, [{ op: "set", index: 1, item: n[1] }]);
});

test("diffList reorder: correct, kept items not removed/inserted", () => {
  const o = [ev("1"), ev("2"), ev("3"), ev("4")];
  const n = [ev("3"), ev("1"), ev("2"), ev("4")];
  const ops = C.diffList(o, n);
  assert.ok(ops.length > 0);
  assert.ok(ops.every((p) => p.op === "move"), JSON.stringify(ops));
  assert.deepEqual(C.applyOps(clone(o), ops), n);
});

test("applyOps does not mutate input and returns new array", () => {
  const o = [ev("1"), ev("2")];
  const snap = clone(o);
  const r = C.applyOps(o, [{ op: "remove", index: 0 },
    { op: "insert", index: 0, item: ev("9") }, { op: "move", from: 0, to: 1 },
    { op: "set", index: 0, item: ev("8") }]);
  assert.deepEqual(o, snap);
  assert.notEqual(r, o);
  assert.deepEqual(C.applyOps(o, []), o);
  assert.notEqual(C.applyOps(o, []), o);
});

function prng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

test("diffList property: applyOps(old, diff) == new (400 random cases)", () => {
  const rnd = prng(12345);
  const pick = (a) => a[Math.floor(rnd() * a.length)];
  const mk = (id) => ev(String(id), {
    title: pick(["a", "b", "c"]), location: pick(["1", "2", ""]),
    calendar: pick(["X", "Y"]), "end-time": pick(["09:00", "10:00"]),
  });
  for (let it = 0; it < 400; it++) {
    const pool = Array.from({ length: 12 }, (_, i) => i);
    const subset = () => pool.filter(() => rnd() < 0.5);
    const shuffle = (a) => {
      for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(rnd() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
      }
      return a;
    };
    const o = shuffle(subset()).map(mk);
    const n = shuffle(subset()).map(mk);
    const oSnap = clone(o), nSnap = clone(n);
    const ops = C.diffList(o, n);
    assert.deepEqual(o, oSnap);
    assert.deepEqual(n, nSnap);
    assert.deepEqual(C.applyOps(clone(o), ops), n, "iter " + it);
  }
});

test("applyOptimistic add", () => {
  const base = [ev("1")];
  const snap = clone(base);
  const newEv = ev("zz", { uid: "" });
  const r = C.applyOptimistic(base, { id: 7, kind: "add", event: newEv });
  assert.deepEqual(base, snap);
  assert.equal(r.length, 2);
  const added = r.find((e) => e.pending);
  assert.equal(added.pending, true);
  assert.equal(added.uid, "optimistic-7");
  assert.equal(added.title, newEv.title);
  assert.equal(newEv.pending, undefined);
});

test("applyOptimistic edit", () => {
  const base = [ev("1"), ev("2")];
  const snap = clone(base);
  const r = C.applyOptimistic(base, { id: 1, kind: "edit", uid: "2@x",
    event: ev("2", { title: "new" }) });
  assert.deepEqual(base, snap);
  assert.equal(r.length, 2);
  assert.equal(r[1].title, "new");
  assert.equal(r[1].pending, true);
  assert.equal(r[0].pending, undefined);
});

test("applyOptimistic delete", () => {
  const base = [ev("1"), ev("2")];
  const snap = clone(base);
  const r = C.applyOptimistic(base, { id: 1, kind: "delete", uid: "1@x" });
  assert.deepEqual(base, snap);
  assert.deepEqual(r.map((e) => e.uid), ["2@x"]);
});

test("applyOptimistic unknown uid -> unchanged copy", () => {
  const base = [ev("1")];
  for (const m of [{ id: 1, kind: "edit", uid: "nope", event: ev("q") },
    { id: 2, kind: "delete", uid: "nope" }]) {
    const r = C.applyOptimistic(base, m);
    assert.deepEqual(r, base);
    assert.notEqual(r, base);
  }
});

// reconcilePending: a revalidation landed while mutations are still in flight.
test("reconcilePending: nothing pending -> fresh as is", () => {
  const fresh = [ev("1"), ev("2")];
  assert.deepEqual(C.reconcilePending(fresh, []), fresh);
});

test("reconcilePending: in-flight add stays visible", () => {
  const fresh = [ev("1")];
  const add = { id: 3, kind: "add", event: ev("new", { title: "Лекция", uid: undefined }) };
  const r = C.reconcilePending(fresh, [add]);
  assert.equal(r.length, 2);
  assert.equal(r[1].uid, "optimistic-3");
  assert.equal(r[1].pending, true);
});

test("reconcilePending: in-flight delete keeps the row hidden", () => {
  const fresh = [ev("1"), ev("2")];
  const r = C.reconcilePending(fresh, [{ id: 1, kind: "delete", uid: "1@x" }]);
  assert.deepEqual(r.map((e) => e.uid), ["2@x"]);
});

test("reconcilePending: in-flight edit wins over the server copy", () => {
  const fresh = [ev("1", { title: "old" })];
  const edit = { id: 2, kind: "edit", uid: "1@x", event: ev("1", { title: "new" }) };
  const r = C.reconcilePending(fresh, [edit]);
  assert.equal(r.length, 1);
  assert.equal(r[0].title, "new");
  assert.equal(r[0].pending, true);
});

test("reconcilePending: an add that already reached the server is not shown twice", () => {
  // khal wrote the .ics before the mutation process exited (it still syncs),
  // so the fresh rows already contain the real event under its real uid.
  const draft = { title: "Лекция", "start-date": "2026-11-07", "start-time": "12:00",
    "end-time": "13:30", location: "345", calendar: "Дом" };
  const fresh = [ev("1"), Object.assign({}, draft, { uid: "real-uid@icloud" })];
  const r = C.reconcilePending(fresh, [{ id: 9, kind: "add", event: draft }]);
  assert.equal(r.length, 2);
  assert.equal(r.filter((e) => e.title === "Лекция").length, 1);
  assert.ok(!r.some((e) => e.uid === "optimistic-9"));
});

test("reconcilePending: does not mutate inputs", () => {
  const fresh = [ev("1")];
  const pending = [{ id: 1, kind: "delete", uid: "1@x" }];
  const snap = clone({ fresh, pending });
  C.reconcilePending(fresh, pending);
  assert.deepEqual({ fresh, pending }, snap);
});
