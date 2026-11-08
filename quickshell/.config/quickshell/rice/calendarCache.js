.pragma library

function eventKey(ev) {
    return ev["uid"] + "|" + ev["start-date"] + "|" + ev["start-time"]
}

function pad2(n) {
    return (n < 10 ? "0" : "") + n
}

function monthKey(year, month0) {
    return year + "-" + pad2(month0 + 1)
}

function neighborMonths(key) {
    var y = parseInt(key.slice(0, 4), 10)
    var m0 = parseInt(key.slice(5, 7), 10) - 1
    var py = m0 === 0 ? y - 1 : y
    var pm = m0 === 0 ? 11 : m0 - 1
    var ny = m0 === 11 ? y + 1 : y
    var nm = m0 === 11 ? 0 : m0 + 1
    return [monthKey(py, pm), monthKey(ny, nm)]
}

function parseMonth(text) {
    if (typeof text !== "string")
        return null
    var a = text.indexOf("{")
    var b = text.lastIndexOf("}")
    if (a < 0 || b <= a)
        return null
    var o
    try {
        o = JSON.parse(text.slice(a, b + 1))
    } catch (e) {
        return null
    }
    if (!o || typeof o !== "object" || !Array.isArray(o.events))
        return null
    return { month: o.month, fetchedAt: o.fetchedAt, events: o.events }
}

function eventsForDay(events, isoDate) {
    var out = []
    for (var i = 0; i < events.length; i++)
        if (events[i]["start-date"] === isoDate)
            out.push(events[i])
    return out
}

function dayDots(events) {
    var out = {}
    for (var i = 0; i < events.length; i++) {
        var e = events[i]
        var cal = e["calendar"]
        if (!cal)
            continue
        var day = String(parseInt(String(e["start-date"]).slice(8, 10), 10))
        if (!out[day])
            out[day] = []
        if (out[day].indexOf(cal) < 0)
            out[day].push(cal)
    }
    return out
}

function dotsEqual(a, b) {
    var ka = Object.keys(a), kb = Object.keys(b)
    if (ka.length !== kb.length)
        return false
    for (var i = 0; i < ka.length; i++) {
        var x = a[ka[i]], y = b[ka[i]]
        if (!y || x.length !== y.length)
            return false
        for (var j = 0; j < x.length; j++)
            if (x[j] !== y[j])
                return false
    }
    return true
}

function eventChanged(a, b) {
    var f = ["title", "start-time", "end-time", "location", "calendar"]
    for (var i = 0; i < f.length; i++)
        if (a[f[i]] !== b[f[i]])
            return true
    return !!a.pending !== !!b.pending
}

// Assumes keys are normally unique; duplicate keys are handled by multiset counts.
function diffList(oldItems, newItems) {
    var ops = []
    var need = {}
    var i
    for (i = 0; i < newItems.length; i++) {
        var nk = eventKey(newItems[i])
        need[nk] = (need[nk] || 0) + 1
    }
    var cur = []
    var keep = []
    for (i = oldItems.length - 1; i >= 0; i--) {
        var k = eventKey(oldItems[i])
        if (need[k] > 0) {
            need[k]--
            keep.push(true)
        } else {
            keep.push(false)
            ops.push({ op: "remove", index: i })
        }
    }
    keep.reverse()
    for (i = 0; i < oldItems.length; i++)
        if (keep[i])
            cur.push(oldItems[i])
    var curKeys = cur.map(eventKey)

    for (i = 0; i < newItems.length; i++) {
        var key = eventKey(newItems[i])
        if (i < curKeys.length && curKeys[i] === key) {
            if (eventChanged(cur[i], newItems[i]))
                ops.push({ op: "set", index: i, item: newItems[i] })
            continue
        }
        var from = curKeys.indexOf(key, i + 1)
        if (from >= 0) {
            var it = cur.splice(from, 1)[0]
            curKeys.splice(from, 1)
            cur.splice(i, 0, it)
            curKeys.splice(i, 0, key)
            ops.push({ op: "move", from: from, to: i })
            if (eventChanged(it, newItems[i]))
                ops.push({ op: "set", index: i, item: newItems[i] })
        } else {
            cur.splice(i, 0, newItems[i])
            curKeys.splice(i, 0, key)
            ops.push({ op: "insert", index: i, item: newItems[i] })
        }
    }
    return ops
}

function applyOps(array, ops) {
    var a = array.slice()
    for (var i = 0; i < ops.length; i++) {
        var o = ops[i]
        if (o.op === "remove")
            a.splice(o.index, 1)
        else if (o.op === "insert")
            a.splice(o.index, 0, o.item)
        else if (o.op === "move")
            a.splice(o.to, 0, a.splice(o.from, 1)[0])
        else if (o.op === "set")
            a[o.index] = o.item
    }
    return a
}

function copyEvent(ev, extra) {
    var o = {}
    for (var k in ev)
        o[k] = ev[k]
    for (var k2 in extra)
        o[k2] = extra[k2]
    return o
}

function applyOptimistic(events, m) {
    var out = []
    var i
    if (m.kind === "add") {
        for (i = 0; i < events.length; i++)
            out.push(events[i])
        if (m.event)
            out.push(copyEvent(m.event, { uid: "optimistic-" + m.id, pending: true }))
        return out
    }
    for (i = 0; i < events.length; i++) {
        var e = events[i]
        if (e.uid === m.uid) {
            if (m.kind === "delete")
                continue
            if (m.kind === "edit" && m.event) {
                out.push(copyEvent(m.event, { pending: true }))
                continue
            }
        }
        out.push(e)
    }
    return out
}

// fresh: rows from the latest `month` fetch (server truth, no pending flags).
// pending: in-flight mutations in submit order, {id, kind:"add"|"edit"|"delete", event?, uid?}.
// Returns the rows to render. Must not mutate either input.
// applyOptimistic(rows, m) already knows how to lay one mutation over rows.
function reconcilePending(fresh, pending) {
    var rows = fresh.slice()
    for (var i = 0; i < pending.length; i++) {
        var m = pending[i]
        // `add` writes the .ics before it syncs, so a revalidation can already
        // carry the real event under its real uid: show that one, not a copy.
        if (m.kind === "add" && m.event && rows.some(function (r) { return sameSlot(r, m.event) }))
            continue
        // An edit whose uid vanished from fresh was deleted elsewhere: server wins.
        rows = applyOptimistic(rows, m)
    }
    return rows
}

function sameSlot(a, b) {
    return !a.pending && a.title === b.title
        && a["start-date"] === b["start-date"] && a["start-time"] === b["start-time"]
}
