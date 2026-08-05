import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RicePanel {
    id: root

    property var entries: []
    property var filtered: []
    property var locationRows: []
    property var favoriteKeys: [] // city keys, lowercased for membership
    property string bestLabel: "Best location"
    property string bestNode: ""
    property string bestPing: ""
    property string statusText: "…"
    property bool connected: false
    property string currentKey: ""
    property string currentLabel: ""
    property bool loading: false
    property bool busy: false
    property string busyAction: ""
    property string busyTarget: ""
    property string busyLabel: ""
    property bool wantLocations: true
    property int busyPolls: 0
    property bool locationsCached: false
    property int pingRefreshTicks: 0
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/qs-vpn.sh"
    readonly property string spinGlyph: {
        const frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        return frames[spinTick % frames.length]
    }
    property int spinTick: 0
    readonly property bool onBest: {
        if (!connected || !bestNode)
            return false
        const hay = ((currentLabel || "") + " " + (currentKey || "")).toLowerCase()
        const parts = bestNode.split("·")
        for (let i = 0; i < parts.length; i++) {
            const p = parts[i].trim().toLowerCase()
            if (p.length > 0 && hay.indexOf(p) >= 0)
                return true
        }
        return hay.indexOf(bestNode.toLowerCase()) >= 0
    }

    title: "VPN"
    searchPlaceholder: "Search locations…"
    footerText: busy
        ? (spinGlyph + " " + (busyAction === "disconnect" ? "disconnecting…" : ("connecting" + (busyLabel ? (" " + busyLabel) : "") + "…")) + "  ·  ↵ cancel  ·  esc cancel")
        : (connected
            ? "↑↓ move  ·  ↵ active = OFF  ·  ⇧↵ fav"
            : "↑↓ move  ·  ↵ connect  ·  ⇧↵ fav  ·  esc close")
    model: filtered
    countText: {
        if (loading || busy)
            return spinGlyph + " " + statusText
        if (connected && currentLabel)
            return "ON · " + currentLabel
        if (connected)
            return "ON"
        return "OFF"
    }
    itemHeight: Theme.rowHeight
    maxVisible: 10
    panelHeight: 560

    onPanelOpened: {
        wantLocations = true
        pingRefreshTicks = 0
        if (!locationsCached) {
            locationRows = []
            loading = true
        } else {
            loading = false
        }
        if (!busy)
            statusText = "…"
        rebuild()
        statusProc.running = true
        favsProc.running = true
        if (busy) {
            if (!pollTimer.running)
                pollTimer.start()
        }
        pendingProc.running = true
        pingPollTimer.restart()
    }
    onPanelClosed: {
        if (!busy) {
            pollTimer.stop()
            busyWatchdog.stop()
        }
        pingPollTimer.stop()
    }
    onQueryChanged: applyFilter()
    onActivated: (item, index) => runAction(item)

    Timer {
        running: root.loading || root.busy
        interval: 80
        repeat: true
        onTriggered: root.spinTick = (root.spinTick + 1) % 10
    }

    Timer {
        id: pollTimer
        interval: 500
        repeat: true
        onTriggered: {
            root.busyPolls += 1
            if (!statusProc.running)
                statusProc.running = true
            if (!pendingProc.running)
                pendingProc.running = true
            if (root.busyPolls >= 90)
                root.finishBusy()
        }
    }

    Timer {
        id: busyWatchdog
        interval: 55000
        repeat: false
        onTriggered: root.finishBusy()
    }

    // Pick up background ping-refresh results a few times after open.
    Timer {
        id: pingPollTimer
        interval: 1800
        repeat: true
        onTriggered: {
            root.pingRefreshTicks += 1
            if (!locationsProc.running)
                locationsProc.running = true
            if (root.pingRefreshTicks >= 4)
                stop()
        }
    }

    function locationLabelFor(key) {
        if (!key)
            return ""
        const k = key.toLowerCase()
        for (let i = 0; i < locationRows.length; i++) {
            if (locationRows[i].key.toLowerCase() === k)
                return locationRows[i].label || locationRows[i].key
        }
        return ""
    }

    function locationPingFor(key) {
        if (!key)
            return ""
        const k = key.toLowerCase()
        for (let i = 0; i < locationRows.length; i++) {
            if (locationRows[i].key.toLowerCase() === k)
                return locationRows[i].ping || ""
        }
        return ""
    }

    function favKeyFromItem(item) {
        if (!item || item.kind !== "location")
            return ""
        // Active sticky row → always the connected city, never a nickname/node.
        if (item.current || item.action === "disconnect")
            return root.currentKey || item.key || item.target || ""
        if (item.action === "best" || item.action === "cancel")
            return ""
        const k = item.key || item.target || ""
        if (!k || k === "best" || k === "cancel")
            return ""
        return k
    }

    customKeyHandler: event => {
        if (root.busy && event.key === Qt.Key_Escape) {
            cancelAction()
            return true
        }
        if (!root.busy
                && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ShiftModifier)) {
            const item = filtered[selectedIndex]
            const favKey = favKeyFromItem(item)
            if (favKey) {
                toggleFavorite(favKey)
                return true
            }
            // Consume Shift+Enter even if we can't fav, so it never disconnects.
            return true
        }
        if (event.key === Qt.Key_Down) {
            moveActionable(1)
            return true
        }
        if (event.key === Qt.Key_Up) {
            moveActionable(-1)
            return true
        }
        return false
    }

    function isActionable(item) {
        if (!item || item.kind === "header" || item.kind === "empty")
            return false
        if (item.action === "cancel")
            return true
        if (root.busy)
            return false
        return !!(item.action && item.action !== "noop")
    }

    function firstActionableIndex() {
        for (let i = 0; i < filtered.length; i++) {
            if (isActionable(filtered[i]))
                return i
        }
        return 0
    }

    function moveActionable(delta) {
        if (!filtered || filtered.length === 0)
            return
        let i = selectedIndex
        for (let n = 0; n < filtered.length; n++) {
            i = (i + delta + filtered.length) % filtered.length
            if (isActionable(filtered[i])) {
                selectedIndex = i
                listView.positionViewAtIndex(selectedIndex, ListView.Contain)
                return
            }
        }
    }

    function isFavorite(key) {
        if (!key)
            return false
        const k = key.toLowerCase()
        for (let i = 0; i < favoriteKeys.length; i++) {
            if (favoriteKeys[i] === k)
                return true
        }
        return false
    }

    function parseFavs(text) {
        const keys = []
        const lines = (text || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const k = lines[i].trim()
            if (k)
                keys.push(k.toLowerCase())
        }
        favoriteKeys = keys
    }

    function toggleFavorite(key) {
        if (!key || key === "best")
            return
        const k = key.toLowerCase()
        const next = []
        let removed = false
        for (let i = 0; i < favoriteKeys.length; i++) {
            if (favoriteKeys[i] === k) {
                removed = true
                continue
            }
            next.push(favoriteKeys[i])
        }
        if (!removed)
            next.push(k)
        favoriteKeys = next
        rebuild()
        Quickshell.execDetached(["bash", helper, "fav-toggle", key])
    }

    function parseStatus(statusLine) {
        const line = (statusLine || "").trim() || "OFF"
        statusText = line
        const connecting = /Connecting/i.test(line)
        const disconnecting = /Disconnecting/i.test(line)
        connected = /^ON\b/.test(line) && !connecting
        if (connecting || disconnecting)
            return
        currentKey = ""
        currentLabel = ""
        if (!connected)
            return
        const sep = line.indexOf("·")
        let loc = sep >= 0 ? line.slice(sep + 1).trim() : ""
        if (!loc || /^connected$/i.test(loc))
            return
        const dash = loc.indexOf(" - ")
        const city = dash >= 0 ? loc.slice(0, dash).trim() : loc
        currentKey = city
        currentLabel = loc
    }

    function applyPending(line) {
        const t = (line || "").trim()
        if (!t)
            return false
        const parts = t.split("|")
        if (parts.length < 1)
            return false
        const action = parts[0]
        const target = parts[1] || ""
        const label = parts[2] || target
        busy = true
        busyAction = action
        busyTarget = target
        busyLabel = label
        if (action === "disconnect")
            statusText = "… Disconnecting"
        else
            statusText = "… Connecting" + (label ? (": " + label) : "")
        if (!pollTimer.running)
            pollTimer.start()
        if (!busyWatchdog.running)
            busyWatchdog.restart()
        return true
    }

    function splitFields(line) {
        // city|label|ping  (ping optional)
        const parts = []
        let start = 0
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "|") {
                parts.push(line.slice(start, i))
                start = i + 1
                if (parts.length === 2)
                    break
            }
        }
        parts.push(line.slice(start))
        return parts
    }

    function parseLocations(text) {
        const rows = []
        let best = "Best location"
        let bestPing = ""
        const lines = (text || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (!line)
                continue
            if (/already running|aborting|error:|spdlog|cli:/i.test(line))
                continue
            const parts = splitFields(line)
            if (parts.length < 2)
                continue
            const key = (parts[0] || "").trim()
            const label = (parts[1] || "").trim() || key
            const ping = (parts[2] || "").trim()
            if (!key)
                continue
            if (key === "best" || /^best location/i.test(label)) {
                best = label.indexOf("Best location") === 0 ? label : ("Best location (" + label + ")")
                bestPing = /^\d+$/.test(ping) ? ping : ""
                const open = best.lastIndexOf("(")
                const close = best.lastIndexOf(")")
                root.bestNode = (open >= 0 && close > open)
                    ? best.slice(open + 1, close).trim()
                    : ""
                continue
            }
            rows.push({
                key: key,
                label: label,
                ping: /^\d+$/.test(ping) ? ping : ""
            })
        }
        // Native Timsort — O(n log n), stable, ideal for ~100–200 cities.
        // Ascending latency; unknown ping last; tie-break by label.
        rows.sort((a, b) => {
            const pa = a.ping === "" ? Number.POSITIVE_INFINITY : (+a.ping)
            const pb = b.ping === "" ? Number.POSITIVE_INFINITY : (+b.ping)
            if (pa !== pb)
                return pa - pb
            return (a.label || a.key).localeCompare(b.label || b.key)
        })
        bestLabel = best
        root.bestPing = bestPing
        locationRows = rows
        locationsCached = rows.length > 0
    }

    function rowIsBusy(key, action) {
        if (!busy)
            return false
        if (busyAction === "best" && (action === "best" || key === "best"))
            return true
        if (busyAction === "disconnect" && key && (
                (currentKey && key.toLowerCase() === currentKey.toLowerCase())
                || (busyTarget && key.toLowerCase() === busyTarget.toLowerCase())
            ))
            return true
        if ((busyAction === "connect" || busyAction === "best") && key
                && busyTarget && key.toLowerCase() === busyTarget.toLowerCase())
            return true
        return false
    }

    function pingText(ms) {
        return ms ? (ms + " ms") : ""
    }

    function makeLocationRow(row, opts) {
        const isCurrent = !!(opts && opts.isCurrent)
        const thisBusy = isCurrent
            ? rowIsBusy(row.key, "disconnect")
            : rowIsBusy(row.key, "connect")
        return {
            kind: "location",
            label: thisBusy
                ? (isCurrent || busyAction === "disconnect" ? "Disconnecting…" : "Connecting…")
                : row.label,
            detail: thisBusy ? "" : pingText(row.ping),
            action: busy ? "noop" : (isCurrent ? "disconnect" : "connect"),
            target: row.key,
            key: row.key,
            ping: row.ping || "",
            favorite: isFavorite(row.key),
            current: isCurrent && !thisBusy,
            busy: thisBusy,
            section: (opts && opts.section) || "all"
        }
    }

    function rebuild() {
        const list = []

        if (busy) {
            list.push({
                kind: "location",
                label: "Cancel " + (busyAction === "disconnect" ? "disconnect" : "connect"),
                action: "cancel",
                target: "cancel",
                key: "",
                detail: "",
                busy: false,
                current: false,
                favorite: false
            })
        }

        if (loading && locationRows.length === 0) {
            list.push({
                kind: "empty",
                label: "Loading regions…",
                action: "noop"
            })
        } else if (!loading && locationRows.length === 0) {
            list.push({
                kind: "empty",
                label: "No regions available",
                action: "noop"
            })
        } else {
            if (connected && (currentLabel || currentKey) && !busy) {
                // Same label scheme as the list ("Finland · Helsinki"), not "Helsinki - Sauna".
                const listLabel = locationLabelFor(currentKey)
                const curPing = locationPingFor(currentKey)
                const base = listLabel || currentKey || currentLabel
                list.push({
                    kind: "location",
                    label: onBest ? (base + " (best location)") : base,
                    detail: pingText(curPing),
                    action: "disconnect",
                    target: currentKey,
                    key: currentKey,
                    ping: curPing,
                    favorite: isFavorite(currentKey),
                    current: true
                })
            }

            const bestBusy = rowIsBusy("best", "best")
            const bestIsActive = onBest && connected && !busy
            if (!bestIsActive) {
                list.push({
                    kind: "location",
                    label: bestBusy ? "Connecting…" : bestLabel,
                    action: busy ? "noop" : "best",
                    detail: bestBusy ? "" : pingText(bestPing),
                    target: "best",
                    key: "best",
                    ping: bestPing,
                    favorite: false,
                    current: false,
                    busy: bestBusy
                })
            }

            // Favorites section (also by latency)
            const favRows = []
            const favSorted = []
            for (let i = 0; i < favoriteKeys.length; i++) {
                const fk = favoriteKeys[i]
                let row = null
                for (let j = 0; j < locationRows.length; j++) {
                    if (locationRows[j].key.toLowerCase() === fk) {
                        row = locationRows[j]
                        break
                    }
                }
                if (!row)
                    row = { key: fk, label: fk, ping: "" }
                favSorted.push(row)
            }
            favSorted.sort((a, b) => {
                const pa = a.ping === "" ? Number.POSITIVE_INFINITY : (+a.ping)
                const pb = b.ping === "" ? Number.POSITIVE_INFINITY : (+b.ping)
                if (pa !== pb)
                    return pa - pb
                return (a.label || a.key).localeCompare(b.label || b.key)
            })
            for (let i = 0; i < favSorted.length; i++) {
                const row = favSorted[i]
                // Sticky already shows ✓ for the active city — Favorites keeps the
                // same "Region · City" label with ★ only (no second checkmark).
                favRows.push(makeLocationRow(row, { isCurrent: false, section: "fav" }))
            }
            if (favRows.length > 0) {
                list.push({ kind: "header", label: "Favorites", action: "noop" })
                for (let i = 0; i < favRows.length; i++)
                    list.push(favRows[i])
                list.push({ kind: "header", label: "All locations", action: "noop" })
            }

            const pendingKey = (busy && busyAction === "connect") ? busyTarget : ""
            if (pendingKey) {
                let pendingInList = false
                for (let i = 0; i < locationRows.length; i++) {
                    if (locationRows[i].key.toLowerCase() === pendingKey.toLowerCase()) {
                        pendingInList = true
                        break
                    }
                }
                if (!pendingInList) {
                    list.push({
                        kind: "location",
                        label: "Connecting…",
                        detail: "",
                        action: "noop",
                        target: pendingKey,
                        key: pendingKey,
                        busy: true,
                        favorite: isFavorite(pendingKey)
                    })
                }
            }

            for (let i = 0; i < locationRows.length; i++) {
                const row = locationRows[i]
                const isCurrent = connected && currentKey
                    && row.key.toLowerCase() === currentKey.toLowerCase()
                if (isCurrent && connected && !busy)
                    continue
                // Skip duplicates already shown under Favorites.
                if (favRows.length > 0 && isFavorite(row.key))
                    continue
                list.push(makeLocationRow(row, { isCurrent: isCurrent, section: "all" }))
            }
        }

        entries = list
        applyFilter()
    }

    function applyFilter() {
        const q = searchText.trim().toLowerCase()
        if (!q) {
            filtered = entries.slice()
        } else {
            const out = []
            let pendingHeader = null
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i]
                if (e.kind === "header") {
                    pendingHeader = e
                    continue
                }
                if (e.kind === "empty") {
                    out.push(e)
                    continue
                }
                const blob = [e.label, e.detail, e.target, e.key].filter(Boolean).join(" ").toLowerCase()
                if (blob.includes(q)) {
                    if (pendingHeader) {
                        out.push(pendingHeader)
                        pendingHeader = null
                    }
                    out.push(e)
                }
            }
            filtered = out
        }
        const first = firstActionableIndex()
        if (!isActionable(filtered[selectedIndex]))
            selectedIndex = first
        clampSelection()
        if (!isActionable(filtered[selectedIndex]))
            selectedIndex = firstActionableIndex()
    }

    function finishBusy() {
        pollTimer.stop()
        busyWatchdog.stop()
        busyWatchdog.interval = 55000
        busy = false
        busyAction = ""
        busyTarget = ""
        busyLabel = ""
        busyPolls = 0
        wantLocations = false
        if (!statusProc.running)
            statusProc.running = true
        else
            rebuild()
    }

    function cancelAction() {
        if (!busy)
            return
        busyAction = "cancel"
        statusText = "… Cancelling"
        busyLabel = "cancel"
        rebuild()
        Quickshell.execDetached(["bash", helper, "cancel"])
        busyPolls = 0
        pollTimer.restart()
        busyWatchdog.interval = 8000
        busyWatchdog.restart()
    }

    function runAction(item) {
        if (!isActionable(item))
            return
        if (item.action === "cancel") {
            cancelAction()
            return
        }
        if (busy)
            return

        busy = true
        busyAction = item.action
        busyTarget = item.target || (item.action === "best" ? "best" : "")
        busyLabel = item.action === "best" ? bestLabel : (item.label || item.target || "")
        busyPolls = 0
        if (item.action === "disconnect")
            statusText = "… Disconnecting"
        else
            statusText = "… Connecting" + (busyLabel ? (": " + busyLabel) : "")
        rebuild()

        let args = ["bash", helper]
        if (item.action === "disconnect")
            args.push("disconnect")
        else if (item.action === "best")
            args.push("best")
        else if (item.action === "connect")
            args.push("connect", item.target || item.label)
        else {
            finishBusy()
            return
        }
        Quickshell.execDetached(args)
        pollTimer.restart()
        busyWatchdog.restart()
    }

    Process {
        id: statusProc
        command: ["bash", root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseStatus(text.trim())

                if (root.wantLocations) {
                    root.wantLocations = false
                    root.rebuild()
                    locationsProc.running = true
                    return
                }

                if (root.busy) {
                    const idle = !/Connecting|Disconnecting|Cancelling/i.test(root.statusText)
                    if (root.busyAction === "cancel" && idle && root.busyPolls >= 1) {
                        root.finishBusy()
                        return
                    }
                    const wantOn = root.busyAction !== "disconnect" && root.busyAction !== "cancel"
                    const settledOn = root.connected && !/Connecting/i.test(root.statusText)
                    const settledOff = !root.connected && idle
                    if (((wantOn && settledOn) || (!wantOn && settledOff)) && root.busyPolls >= 1) {
                        root.finishBusy()
                        return
                    }
                    root.rebuild()
                    return
                }

                root.rebuild()
            }
        }
    }

    Process {
        id: pendingProc
        command: ["bash", root.helper, "pending"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.applyPending(text))
                    root.rebuild()
            }
        }
    }

    Process {
        id: favsProc
        command: ["bash", root.helper, "favs"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseFavs(text)
                root.rebuild()
            }
        }
    }

    Process {
        id: locationsProc
        command: ["bash", root.helper, "locations"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseLocations(text)
                root.loading = false
                root.rebuild()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.loading) {
                root.loading = false
                root.rebuild()
            }
        }
    }

    rowDelegate: Item {
        id: rowRoot
        required property var modelData
        required property int index

        readonly property bool isEmpty: modelData.kind === "empty"
        readonly property bool isHeader: modelData.kind === "header"
        readonly property bool isCurrent: !!(modelData.current)
        readonly property bool isBusyRow: !!(modelData.busy)
        readonly property bool isCancel: modelData.action === "cancel"
        readonly property bool isFav: root.isFavorite(modelData.key || (isCurrent ? root.currentKey : ""))
        readonly property bool selectable: root.isActionable(modelData)
        readonly property bool selected: selectable && index === root.selectedIndex

        width: ListView.view ? ListView.view.width : root.panelWidth - 28
        height: isHeader ? 28 : Theme.rowHeight

        // Section header
        Text {
            visible: isHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            text: modelData.label || ""
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.bold: true
            font.capitalization: Font.AllUppercase
            opacity: 0.85
        }

        Rectangle {
            visible: !isHeader
            anchors.fill: parent
            radius: Theme.radiusSm
            color: {
                if (isEmpty)
                    return "transparent"
                if (selected)
                    return Theme.rowSelected
                if (isCancel)
                    return Theme.surfaceVariant
                if (isBusyRow)
                    return Theme.surfaceVariant
                if (isCurrent)
                    return Theme.glassTileActive
                return Theme.row
            }
            border.width: isCurrent && !selected ? 1 : 0
            border.color: Theme.glassTileBorder
            opacity: root.busy && !isBusyRow && !isCancel && !isEmpty ? 0.55 : 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: {
                        if (isEmpty)
                            return root.loading ? root.spinGlyph : "…"
                        if (isCancel)
                            return "✕"
                        if (isBusyRow)
                            return root.spinGlyph
                        if (isCurrent)
                            return "✓"
                        return "•"
                    }
                    color: selected
                        ? Theme.textOnAccent
                        : (isCurrent ? Theme.primary : Theme.secondary)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    Layout.preferredWidth: 22
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.label || ""
                    color: {
                        if (isEmpty)
                            return Theme.textMuted
                        if (selected)
                            return Theme.textOnAccent
                        if (isCurrent)
                            return Theme.primary
                        return Theme.text
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: isCurrent || isBusyRow
                    elide: Text.ElideRight
                }

                // Favorite mark — only on favourited rows (⇧↵ to add/remove)
                Text {
                    visible: isFav && !isBusyRow && !isEmpty && !isCancel
                    text: "★"
                    color: selected ? Theme.textOnAccent : Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    Layout.preferredWidth: visible ? 22 : 0
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: !root.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = rowRoot.index
                            root.toggleFavorite(modelData.key || root.currentKey)
                        }
                    }
                }

                // Latency
                Text {
                    visible: !isEmpty && !isBusyRow && !!(modelData.detail)
                    text: modelData.detail || ""
                    color: selected ? Theme.textOnAccent : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    opacity: 0.9
                    Layout.preferredWidth: 58
                    horizontalAlignment: Text.AlignRight
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                enabled: selectable
                hoverEnabled: true
                cursorShape: selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: {
                    if (selectable)
                        root.selectedIndex = rowRoot.index
                }
                onClicked: {
                    root.selectedIndex = rowRoot.index
                    root.activateSelected()
                }
            }
        }
    }
}
