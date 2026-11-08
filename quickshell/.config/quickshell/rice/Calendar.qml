pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "ds" as DS
import "calendarCache.js" as CC

PanelWindow {
    id: root

    property bool open: false
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property int selectedDay: new Date().getDate()
    property var eventDays: ({}) // { "1": ["Рабочий","Домашний"], ... } (khal calendar names)
    property int eventDaysRev: 0
    // Stale-while-revalidate state. monthCache: { "YYYY-MM": {fetchedAt, events} }.
    property var monthCache: ({})
    property bool monthLoaded: false // visible month has a cache entry
    property var shownRows: []       // raw rows mirrored in eventsModel
    property var pendingMutations: []
    property int mutSeq: 0
    property var curMut: null
    property var fetchQueue: []
    property string curKey: ""
    property string openFlowKey: ""
    readonly property bool fetching: fetchQueue.length > 0 || curKey !== ""
    // Filled from `qs-calendar.sh calendars`: every calendar khal knows, so
    // calendars added in Apple/Google show up without touching this file.
    property var calColors: ({})
    property var calendarList: [] // [{ id, label, color, readOnly, isDefault }]
    property string defaultCalendar: ""

    property bool formOpen: false
    property bool formEditing: false
    property string editUid: ""
    property bool busy: false
    property string statusText: ""

    property string draftTitle: ""
    property string draftLocation: ""
    property string draftCalendar: root.defaultCalendar
    property bool draftAllDay: false
    property int draftStartH: 10
    property int draftStartM: 0
    property int draftEndH: 11
    property int draftEndM: 0
    // Bumps every minute so past/upcoming styling stays live.
    property int nowTick: 0

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/qs-calendar.sh"
    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    function pad2(n) { return String(n).padStart(2, "0") }

    function selectedIso() {
        return viewYear + "-" + pad2(viewMonth + 1) + "-" + pad2(selectedDay)
    }

    function monthKey() {
        return viewYear + "-" + pad2(viewMonth + 1)
    }

    function timeStr(h, m) { return pad2(h) + ":" + pad2(m) }

    function parseHm(s, fallbackH, fallbackM) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(s || "").trim())
        if (!m)
            return { h: fallbackH, m: fallbackM }
        return {
            h: Math.max(0, Math.min(23, parseInt(m[1], 10))),
            m: Math.max(0, Math.min(59, parseInt(m[2], 10)))
        }
    }

    function monthCells() {
        const first = new Date(viewYear, viewMonth, 1)
        const start = (first.getDay() + 6) % 7
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        const today = new Date()
        const isCurrentMonth = today.getFullYear() === viewYear && today.getMonth() === viewMonth
        const cells = []
        for (let i = 0; i < start; i++)
            cells.push({ day: 0, today: false, cals: [] })
        for (let d = 1; d <= daysInMonth; d++) {
            cells.push({
                day: d,
                today: isCurrentMonth && d === today.getDate(),
                cals: []
            })
        }
        return cells
    }

    function shiftMonth(delta) {
        let m = viewMonth + delta
        let y = viewYear
        while (m < 0) { m += 12; y -= 1 }
        while (m > 11) { m -= 12; y += 1 }
        viewYear = y
        viewMonth = m
        const maxDay = new Date(y, m + 1, 0).getDate()
        if (selectedDay > maxDay)
            selectedDay = maxDay
        formOpen = false
        viewChanged()
    }

    function goToday() {
        const now = new Date()
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
        selectedDay = now.getDate()
        formOpen = false
        viewChanged()
    }

    // Visible month changed: paint from cache now, revalidate in the background.
    function viewChanged() {
        root.render()
        const key = root.monthKey()
        root.fetchMonth(key, true)
        root.prefetchNeighbors(key)
    }

    function calAccent(name) {
        return root.calColors[name] || DS.Tokens.textTertiary
    }

    function sceneGeom(outsideBand) {
        const scr = root.screen
        const ox = scr ? Math.round(scr.x) : 0
        const oy = scr ? Math.round(scr.y) : 0
        const sw = scr ? Math.round(scr.width) : 0
        const w = Math.round(root.implicitWidth)
        let h = Math.round(root.implicitHeight)
        if (w < 32)
            return ""
        if (h < 32)
            h = 420
        let gx = ox + sw - root.margins.right - w
        let gy = oy + root.margins.top
        if (gx < 0)
            gx = 0
        if (gy < 0)
            gy = 0
        if (outsideBand) {
            const band = 28
            const by = Math.max(0, gy - band)
            return gx + "," + by + " " + w + "x" + band
        }
        return gx + "," + gy + " " + w + "x" + h
    }

    function refreshScene(outsideBand) {
        DS.AdaptiveContrast.refresh(root.sceneGeom(!!outsideBand))
    }

    // True if the event is already over relative to "now".
    function isEventPast(ev) {
        void root.nowTick
        const now = new Date()
        const day = new Date(root.viewYear, root.viewMonth, root.selectedDay)
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate())

        if (dayStart < todayStart)
            return true
        if (dayStart > todayStart)
            return false

        const s = String(ev["start-time"] || "")
        const e = String(ev["end-time"] || "")
        // All-day on today stays active until the day ends.
        if (!s && !e)
            return false

        const endHm = e || s
        const m = /^(\d{1,2}):(\d{2})$/.exec(endHm)
        if (!m)
            return false
        const endAt = new Date(root.viewYear, root.viewMonth, root.selectedDay,
                               parseInt(m[1], 10), parseInt(m[2], 10), 0, 0)
        return now >= endAt
    }

    function dayCals(day) {
        void root.eventDaysRev
        const v = root.eventDays ? root.eventDays[String(day)] : null
        if (!Array.isArray(v))
            return []
        // Cap at the number of calendars we actually have, so a busy day
        // never silently drops a marker.
        const cap = Object.keys(root.calColors || {}).length || 7
        return v.slice(0, cap)
    }

    function refreshColors() {
        colorsProc.running = false
        colorsProc.running = true
    }

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/qs-calendar"

    function readDiskMonth(key) {
        try {
            monthFile.path = root.cacheDir + "/months/" + key + ".json"
            return CC.parseMonth(monthFile.text())
        } catch (e) {
            return null
        }
    }

    function cacheEntry(key) {
        let ent = root.monthCache[key]
        if (!ent) {
            const parsed = root.readDiskMonth(key)
            if (parsed) {
                ent = { fetchedAt: parsed.fetchedAt, events: parsed.events }
                root.monthCache[key] = ent
            }
        }
        return ent || null
    }

    function loadCalendarsDisk() {
        try {
            calFile.path = root.cacheDir + "/calendars.json"
            root.applyCalendars(calFile.text())
        } catch (e) {}
    }

    function applyCalendars(raw) {
        try {
            const obj = JSON.parse(String(raw).trim())
            if (!obj || typeof obj !== "object" || Array.isArray(obj))
                return
            const colors = {}
            const list = []
            let def = ""
            for (const id of Object.keys(obj)) {
                const c = obj[id]
                if (c.color)
                    colors[id] = c.color
                if (c.default && !c.readonly)
                    def = id
                list.push({ id: id, label: c.label || id, readOnly: c.readonly === true })
            }
            // Writable calendars first; read-only mirrors trail.
            list.sort((x, y) => Number(x.readOnly) - Number(y.readOnly))
            if (!def) {
                const w = list.find(c => !c.readOnly)
                def = w ? w.id : ""
            }
            root.calColors = colors
            root.calendarList = list
            root.defaultCalendar = def
            if (!root.formOpen || !root.draftCalendar)
                root.draftCalendar = def
        } catch (e) {}
    }

    // ---- serial fetch queue (one Process; khal's sqlite is single-writer) ----
    function fetchMonth(key, urgent) {
        if (root.curKey === key)
            return
        const q = root.fetchQueue.filter(k => k !== key)
        if (urgent)
            q.unshift(key)
        else
            q.push(key)
        root.fetchQueue = q
        root.pumpFetch()
    }

    function prefetchNeighbors(key) {
        const nowS = Date.now() / 1000
        for (const k of CC.neighborMonths(key)) {
            const ent = root.cacheEntry(k)
            if (ent && nowS - (ent.fetchedAt || 0) < 60)
                continue
            root.fetchMonth(k, false)
        }
    }

    function pumpFetch() {
        if (fetchProc.running)
            return
        root.curKey = ""
        if (root.fetchQueue.length === 0)
            return
        const q = root.fetchQueue.slice()
        const key = q.shift()
        root.fetchQueue = q
        root.curKey = key
        fetchProc.command = ["bash", root.script, "month", key]
        fetchProc.running = true
    }

    function fetchFinished(key, text) {
        const parsed = CC.parseMonth(text)
        if (parsed)
            root.monthCache[key] = { fetchedAt: parsed.fetchedAt, events: parsed.events }
        // Mutations the server has now acknowledged are covered by this fetch.
        const left = root.pendingMutations.filter(m => !(m.done && m.month === key))
        if (left.length !== root.pendingMutations.length)
            root.pendingMutations = left
        if (key === root.monthKey())
            root.render()
        if (key === root.openFlowKey) {
            root.openFlowKey = ""
            if (root.open && !syncProc.running)
                root.syncAndRefresh()
        }
    }

    // ---- rendering: patch eventsModel / dots instead of rebuilding ----
    function flatRow(r) {
        return {
            key: CC.eventKey(r),
            title: r.title || "",
            startDate: r["start-date"] || "",
            startTime: r["start-time"] || "",
            endTime: r["end-time"] || "",
            location: r.location || "",
            calendar: r.calendar || "",
            uid: r.uid || "",
            pending: !!r.pending
        }
    }

    function render() {
        const key = root.monthKey()
        const ent = root.cacheEntry(key)
        root.monthLoaded = !!ent
        let merged = CC.reconcilePending(ent ? ent.events : [], root.pendingMutations)
        merged = merged.filter(r => String(r["start-date"]).slice(0, 7) === key)

        const dots = CC.dayDots(merged)
        if (!CC.dotsEqual(root.eventDays || {}, dots)) {
            root.eventDays = dots
            root.eventDaysRev++
        }

        const rows = CC.eventsForDay(merged, root.selectedIso())
            .map((r, i) => ({ r: r, i: i }))
            .sort((a, b) => {
                const x = a.r["start-time"] || ""
                const y = b.r["start-time"] || ""
                return x < y ? -1 : (x > y ? 1 : a.i - b.i)
            })
            .map(o => o.r)

        const ops = CC.diffList(root.shownRows, rows)
        for (const o of ops) {
            if (o.op === "remove")
                eventsModel.remove(o.index)
            else if (o.op === "insert")
                eventsModel.insert(o.index, root.flatRow(o.item))
            else if (o.op === "move")
                eventsModel.move(o.from, o.to, 1)
            else if (o.op === "set")
                eventsModel.set(o.index, root.flatRow(o.item))
        }
        root.shownRows = rows
    }

    function syncAndRefresh() {
        busy = true
        syncProc.running = false
        syncProc.running = true
    }

    function closeForm() {
        formOpen = false
        formEditing = false
        editUid = ""
    }

    function openAdd() {
        formEditing = false
        editUid = ""
        draftTitle = ""
        draftLocation = ""
        draftCalendar = root.defaultCalendar
        draftAllDay = false
        draftStartH = 10
        draftStartM = 0
        draftEndH = 11
        draftEndM = 0
        formOpen = true
        Qt.callLater(() => {
            startTime.setTime(root.draftStartH, root.draftStartM)
            endTime.setTime(root.draftEndH, root.draftEndM)
            titleInput.forceActiveFocus()
        })
    }

    function isReadOnlyCal(name) {
        const n = String(name || "")
        return root.calendarList.some(c => c.id === n && c.readOnly)
    }

    function openEdit(ev) {
        if (isReadOnlyCal(ev.calendar)) {
            statusText = "Только чтение — зеркало внешнего расписания"
            statusClear.start()
            return
        }
        formEditing = true
        editUid = ev.uid || ""
        draftTitle = ev.title || ""
        draftLocation = ev.location || ""
        draftCalendar = ev.calendar || root.defaultCalendar
        const s = String(ev["start-time"] || "")
        const e = String(ev["end-time"] || "")
        draftAllDay = !s && !e
        const ps = parseHm(s, 10, 0)
        const pe = parseHm(e, 11, 0)
        draftStartH = ps.h
        draftStartM = Math.round(ps.m / 5) * 5
        draftEndH = pe.h
        draftEndM = Math.round(pe.m / 5) * 5
        formOpen = true
        Qt.callLater(() => {
            startTime.setTime(root.draftStartH, root.draftStartM)
            endTime.setTime(root.draftEndH, root.draftEndM)
            titleInput.forceActiveFocus()
        })
    }

    function submitForm() {
        const title = draftTitle.trim()
        if (!title) {
            statusText = "Title required"
            return
        }
        const loc = draftLocation.trim()
        const cal = draftCalendar || root.defaultCalendar
        const start = draftAllDay ? "allday" : timeStr(draftStartH, draftStartM)
        const end = draftAllDay ? "allday" : timeStr(draftEndH, draftEndM)
        const ev = {
            "title": title,
            "start-date": root.selectedIso(),
            "start-time": draftAllDay ? "" : start,
            "end-time": draftAllDay ? "" : end,
            "location": loc,
            "calendar": cal
        }
        let cmd
        let mut
        if (formEditing && editUid) {
            ev.uid = editUid
            mut = { kind: "edit", uid: editUid, event: ev }
            cmd = ["bash", root.script, "edit", editUid, root.selectedIso(), start, end, title, loc, cal]
        } else {
            mut = { kind: "add", event: ev }
            cmd = ["bash", root.script, "add", root.selectedIso(), start, end, title, loc, cal]
        }
        root.startMutation(mut, cmd, "Saving…")
        root.closeForm()
    }

    function startMutation(mut, cmd, label) {
        mut.id = ++root.mutSeq
        mut.month = root.monthKey()
        mut.done = false
        busy = true
        statusText = label
        root.pendingMutations = root.pendingMutations.concat([mut])
        root.curMut = mut
        root.render()
        mutProc.command = cmd
        mutProc.running = true
    }

    function deleteCurrent() {
        if (!editUid)
            return
        deleteEvent(editUid)
    }

    function deleteEvent(uid) {
        if (!uid)
            return
        root.startMutation({ kind: "delete", uid: uid },
                           ["bash", root.script, "delete", uid], "Deleting…")
        root.closeForm()
    }

    function toggle() {
        if (open)
            close()
        else
            show()
    }
    function show() {
        root.refreshScene(false)
        open = true
    }
    function close() {
        open = false
        closeForm()
        watchProc.running = false
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop()
            OverlayHub.closeAll()
            // Calendars/colors from disk first, then the live call.
            loadCalendarsDisk()
            refreshColors()
            // Re-anchor on today rather than reusing viewYear/viewMonth: those are
            // initialised once and survive config reloads, so a panel opened after
            // a long uptime (or with a wrong clock at first start) stays parked on
            // a stale month forever. Also refreshes markers before the sync lands.
            goToday()
            // Network sync starts once the visible month's fetch has landed.
            openFlowKey = monthKey()
            watchProc.running = true
            openAnim.play()
            Qt.callLater(() => panel.forceActiveFocus())
        } else {
            openAnim.stop()
            closeForm()
            statusText = ""
            watchProc.running = false
            closeAnim.play()
        }
    }

    onSelectedDayChanged: {
        if (open && !formOpen)
            render()
    }

    // Stay visible through the close animation so it doesn't vanish mid-fade.
    visible: open || closeAnim.running
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    implicitWidth: 360
    implicitHeight: 520
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-calendar"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.barHeight + Theme.barMargin * 2 + 6
        right: Theme.barMargin
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            if (root.open)
                root.refreshScene(true)
        }
    }

    Item {
        id: panel
        anchors.fill: parent
        focus: root.open
        transformOrigin: Item.TopRight
        opacity: 1
        scale: 1
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.formOpen)
                    root.closeForm()
                else
                    root.close()
                event.accepted = true
            }
        }

        RiceOpenAnim {
            id: openAnim
            target: panel
            fromScale: 0.96
        }

        RiceCloseAnim {
            id: closeAnim
            target: panel
            toScale: 0.96
        }

        DS.GlassSurface {
            anchors.fill: parent
            radius: DS.Tokens.radiusSurface

            ColumnLayout {
            anchors.fill: parent
            anchors.margins: DS.Tokens.paddingSurface
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Month pager — arrows glued to the title
                RowLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: prevMouse.containsMouse ? DS.Tokens.raised : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                        }

                        RiceIcon {
                            anchors.centerIn: parent
                            customSource: Qt.resolvedUrl("assets/chevron-left.svg")
                            tint: prevMouse.containsMouse ? DS.Tokens.textPrimary : DS.Tokens.textIcon
                            implicitSize: 14
                            scale: prevMouse.containsMouse ? 1.1 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }
                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(-1)
                        }
                    }

                    DS.QuietText {
                        text: root.monthNames[root.viewMonth] + " " + root.viewYear
                        color: DS.Tokens.textPrimary
                        font.family: DS.Tokens.fontUi
                        font.pixelSize: DS.Tokens.fontSize
                        fontWeight: Font.Medium
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                    }

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 12
                        color: nextMouse.containsMouse ? DS.Tokens.raised : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                        }

                        RiceIcon {
                            anchors.centerIn: parent
                            customSource: Qt.resolvedUrl("assets/chevron-right.svg")
                            tint: nextMouse.containsMouse ? DS.Tokens.textPrimary : DS.Tokens.textIcon
                            implicitSize: 14
                            scale: nextMouse.containsMouse ? 1.1 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }
                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    // Identical hit-boxes + glyph size so refresh / add / close match.
                    Repeater {
                        model: [
                            { glyph: "↻", action: "sync" },
                            { glyph: "+", action: "add" },
                            { glyph: "", action: "close" }
                        ]

                        Rectangle {
                            id: hdrBtn
                            required property var modelData
                            property bool hovered: hdrMouse.containsMouse
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: hdrBtn.hovered ? DS.Tokens.raised : "transparent"
                            Behavior on color {
                                ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                            }

                            DS.QuietText {
                                id: glyph
                                anchors.centerIn: parent
                                visible: hdrBtn.modelData.action !== "close"
                                text: hdrBtn.modelData.glyph
                                color: DS.Tokens.textPrimary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSize
                                fontBold: true
                            }

                            RiceIcon {
                                anchors.centerIn: parent
                                visible: hdrBtn.modelData.action === "close"
                                customSource: Qt.resolvedUrl("assets/close.svg")
                                tint: hdrBtn.hovered ? DS.Tokens.textPrimary : DS.Tokens.textIcon
                                implicitSize: 14
                                scale: hdrBtn.hovered ? 1.1 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                id: hdrMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !(hdrBtn.modelData.action === "sync" && root.busy)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (hdrBtn.modelData.action === "sync")
                                        root.syncAndRefresh()
                                    else if (hdrBtn.modelData.action === "add")
                                        root.openAdd()
                                    else
                                        root.close()
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                visible: !root.formOpen
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    DS.QuietText {
                        required property string modelData
                        text: modelData
                        color: DS.Tokens.textTertiary
                        font.family: DS.Tokens.fontUi
                        font.pixelSize: DS.Tokens.fontSizeSection
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                    }
                }

                Repeater {
                    model: root.monthCells()

                    Item {
                        id: cell
                        required property var modelData
                        // Keep day:0 spacers visible so GridLayout preserves Mon–Sun columns.
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        readonly property bool isPad: modelData.day <= 0
                        readonly property bool selected: !isPad && modelData.day === root.selectedDay
                        readonly property bool hovered: !isPad && dayMouse.containsMouse
                        readonly property var cals: cell.isPad ? [] : root.dayCals(modelData.day)

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -4
                            width: 28
                            height: 28
                            radius: 14
                            visible: !cell.isPad
                            color: {
                                if (cell.selected)
                                    return DS.Tokens.raisedStrong
                                if (cell.hovered)
                                    return DS.Tokens.raised
                                return "transparent"
                            }
                            border.width: (cell.selected || (modelData.today && !cell.selected) || cell.hovered) ? 1 : 0
                            border.color: cell.selected
                                ? DS.Tokens.raisedRim
                                : (modelData.today && !cell.selected ? DS.Tokens.fieldRim : DS.Tokens.fieldRim)
                            Behavior on color {
                                ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                            }

                            DS.QuietText {
                                anchors.centerIn: parent
                                text: cell.isPad ? "" : String(cell.modelData.day)
                                color: DS.Tokens.textPrimary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSizeSm
                                fontBold: cell.selected || cell.modelData.today
                            }
                        }

                        // Apple-style event markers under the day number
                        Row {
                            id: dots
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            spacing: cell.cals.length > 1 ? 1 : 0
                            visible: cell.cals.length > 0
                            z: 2

                            Repeater {
                                model: cell.cals

                                Rectangle {
                                    required property var modelData
                                    width: cell.cals.length === 1 ? 6 : 5
                                    height: 5
                                    radius: height / 2
                                    color: root.calAccent(String(modelData))
                                    opacity: 0
                                    Behavior on opacity {
                                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                    }
                                    Component.onCompleted: opacity = 1
                                }
                            }
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            enabled: !cell.isPad
                            hoverEnabled: !cell.isPad
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedDay = cell.modelData.day
                                root.closeForm()
                                root.render()
                            }
                        }
                    }
                }
            }

            Item {
                visible: !root.formOpen
                Layout.fillWidth: true
                Layout.preferredHeight: 8
            }

            RowLayout {
                Layout.fillWidth: true

                DS.QuietText {
                    text: {
                        const d = new Date(root.viewYear, root.viewMonth, root.selectedDay)
                        const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                        return days[d.getDay()] + " · " + root.selectedDay
                    }
                    color: DS.Tokens.textPrimary
                    font.family: DS.Tokens.fontUi
                    font.pixelSize: DS.Tokens.fontSize
                    fontWeight: Font.Medium
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: todayBtn
                    visible: !root.formOpen
                    property bool hovered: todayMouse.containsMouse
                    radius: 12
                    color: todayBtn.hovered ? DS.Tokens.raised : "transparent"
                    border.width: 1
                    border.color: DS.Tokens.fieldRim
                    implicitWidth: todayLbl.implicitWidth + 16
                    implicitHeight: 24
                    Behavior on color {
                        ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                    }

                    DS.QuietText {
                        id: todayLbl
                        anchors.centerIn: parent
                        text: "Today"
                        color: todayBtn.hovered ? DS.Tokens.textPrimary : DS.Tokens.textSecondary
                        font.family: DS.Tokens.fontUi
                        font.pixelSize: DS.Tokens.fontSizeSm
                    }

                    MouseArea {
                        id: todayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToday()
                    }
                }
            }

            // Add / Edit form — scrollable body + sticky footer actions
            ColumnLayout {
                visible: root.formOpen
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                DS.QuietText {
                    text: root.formEditing ? "Edit event" : "New event"
                    color: DS.Tokens.textTertiary
                    font.family: DS.Tokens.fontUi
                    font.pixelSize: DS.Tokens.fontSizeSection
                }

                Flickable {
                    id: formFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: formBody.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    ColumnLayout {
                        id: formBody
                        width: formFlick.width
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                            color: DS.Tokens.fieldFill
                            border.width: 1
                            border.color: titleInput.activeFocus ? DS.Tokens.focusRim : DS.Tokens.fieldRim
                            Behavior on border.color {
                                ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                            }

                            TextInput {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: DS.Tokens.textPrimary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSize
                                selectedTextColor: DS.Tokens.textPrimary
                                text: root.draftTitle
                                onTextChanged: root.draftTitle = text
                                Keys.onReturnPressed: root.submitForm()

                                DS.QuietText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Title"
                                    color: DS.Tokens.textTertiary
                                    font.family: DS.Tokens.fontUi
                                    font.pixelSize: DS.Tokens.fontSize
                                    visible: titleInput.text.length === 0
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            DS.QuietText {
                                text: "All-day"
                                color: DS.Tokens.textPrimary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSizeSm
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 42
                                height: 24
                                radius: 12
                                color: root.draftAllDay ? DS.Tokens.raisedStrong : "transparent"
                                border.width: 1
                                border.color: root.draftAllDay ? DS.Tokens.raisedRim : DS.Tokens.fieldRim
                                Behavior on color {
                                    ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: root.draftAllDay ? parent.width - width - 3 : 3
                                    color: DS.Tokens.textPrimary
                                    Behavior on x {
                                        NumberAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.draftAllDay = !root.draftAllDay
                                }
                            }
                        }

                        RowLayout {
                            visible: !root.draftAllDay
                            Layout.fillWidth: true
                            spacing: 10

                            CalendarTimeWheel {
                                id: startTime
                                label: "Starts"
                                onHourChanged: root.draftStartH = hour
                                onMinuteChanged: root.draftStartM = minute
                            }

                            CalendarTimeWheel {
                                id: endTime
                                label: "Ends"
                                onHourChanged: root.draftEndH = hour
                                onMinuteChanged: root.draftEndM = minute
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                            color: DS.Tokens.fieldFill
                            border.width: 1
                            border.color: locationInput.activeFocus ? DS.Tokens.focusRim : DS.Tokens.fieldRim
                            Behavior on border.color {
                                ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                            }

                            TextInput {
                                id: locationInput
                                anchors.fill: parent
                                anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: DS.Tokens.textPrimary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSizeSm
                                selectedTextColor: DS.Tokens.textPrimary
                                text: root.draftLocation
                                onTextChanged: root.draftLocation = text

                                DS.QuietText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Location (optional)"
                                    color: DS.Tokens.textTertiary
                                    font.family: DS.Tokens.fontUi
                                    font.pixelSize: DS.Tokens.fontSizeSm
                                    visible: locationInput.text.length === 0
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: root.calendarList

                                Rectangle {
                                    id: calChip
                                    required property var modelData
                                    property bool hovered: chipMouse.containsMouse
                                    readonly property bool readOnly: calChip.modelData.readOnly === true
                                    readonly property bool active: !calChip.readOnly && root.draftCalendar === calChip.modelData.id
                                    opacity: calChip.readOnly ? 0.5 : 1
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                                    color: {
                                        if (calChip.active)
                                            return DS.Tokens.raisedStrong
                                        if (calChip.hovered)
                                            return DS.Tokens.raised
                                        return "transparent"
                                    }
                                    border.width: 1
                                    border.color: calChip.active ? DS.Tokens.raisedRim : DS.Tokens.fieldRim
                                    Behavior on color {
                                        ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: root.calAccent(modelData.id)
                                        }
                                        DS.QuietText {
                                            text: modelData.label
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: calChip.width - 30
                                            color: calChip.active ? DS.Tokens.textPrimary : DS.Tokens.textSecondary
                                            font.family: DS.Tokens.fontUi
                                            font.pixelSize: DS.Tokens.fontSizeSm
                                        }
                                    }

                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent
                                        enabled: !calChip.readOnly
                                        hoverEnabled: !calChip.readOnly
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.draftCalendar = modelData.id
                                    }
                                }
                            }
                        }
                    }
                }

                // Sticky footer — always visible
                Rectangle {
                    id: deleteBtn
                    visible: root.formEditing
                    property bool hovered: deleteMouse.containsMouse
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, deleteBtn.hovered ? 0.22 : 0.15)
                    border.width: 1
                    border.color: Theme.error
                    opacity: root.busy ? 0.5 : 1
                    Behavior on color {
                        ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        RiceIcon {
                            name: "edit-delete"
                            fallback: "user-trash"
                            implicitSize: 14
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                        }
                        DS.QuietText {
                            text: "Delete event"
                            color: Theme.error
                            font.family: DS.Tokens.fontUi
                            font.pixelSize: DS.Tokens.fontSizeSm
                            fontBold: true
                        }
                    }

                    MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteCurrent()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        id: cancelBtn
                        property bool hovered: cancelMouse.containsMouse
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                        color: cancelBtn.hovered ? DS.Tokens.raised : "transparent"
                        border.width: 1
                        border.color: DS.Tokens.fieldRim
                        Behavior on color {
                            ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                        }

                        DS.QuietText {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: DS.Tokens.textSecondary
                            font.family: DS.Tokens.fontUi
                            font.pixelSize: DS.Tokens.fontSizeSm
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeForm()
                        }
                    }

                    Rectangle {
                        id: submitBtn
                        property bool hovered: submitMouse.containsMouse
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                        color: submitBtn.hovered ? DS.Tokens.raisedStrong : DS.Tokens.raisedStrong
                        border.width: 1
                        border.color: DS.Tokens.raisedRim
                        opacity: root.busy ? 0.5 : 1

                        DS.QuietText {
                            anchors.centerIn: parent
                            text: root.formEditing ? "Save" : "Add"
                            color: DS.Tokens.textPrimary
                            font.family: DS.Tokens.fontUi
                            font.pixelSize: DS.Tokens.fontSizeSm
                            fontBold: true
                        }

                        MouseArea {
                            id: submitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.busy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submitForm()
                        }
                    }
                }
            }

            // Events list
            ListView {
                id: eventList
                visible: !root.formOpen
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: eventsModel

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: row
                    required property string key
                    required property string title
                    required property string startDate
                    required property string startTime
                    required property string endTime
                    required property string location
                    required property string calendar
                    required property string uid
                    required property bool pending
                    // Original hyphenated shape for the helpers.
                    readonly property var rowObj: ({
                        "uid": row.uid,
                        "title": row.title,
                        "start-date": row.startDate,
                        "start-time": row.startTime,
                        "end-time": row.endTime,
                        "location": row.location,
                        "calendar": row.calendar
                    })
                    width: ListView.view ? ListView.view.width : 0
                    height: ev.height

                    Rectangle {
                    id: ev
                    readonly property bool past: root.isEventPast(row.rowObj)
                    readonly property bool hovered: evMouse.containsMouse
                    width: parent.width
                    height: Math.max(evCol.implicitHeight + 14, 44)
                    radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                    color: ev.hovered && !row.pending ? DS.Tokens.raised : "transparent"
                    border.width: ev.hovered && !row.pending ? 1 : 0
                    border.color: DS.Tokens.raisedRim
                    opacity: row.pending ? 0.6 : (past ? 0.42 : 1.0)
                    Behavior on color {
                        ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: 3
                        radius: 1.5
                        color: root.calAccent(row.calendar)
                        opacity: ev.past ? 0.55 : 1.0
                    }

                    ColumnLayout {
                        id: evCol
                        anchors.left: parent.left
                        anchors.right: trashBtn.left
                        anchors.top: parent.top
                        anchors.leftMargin: 18
                        anchors.rightMargin: 8
                        anchors.topMargin: 7
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true

                            DS.QuietText {
                                text: row.title || "Event"
                                color: DS.Tokens.textPrimary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSize
                                fontBold: !ev.past
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            DS.QuietText {
                                text: {
                                    const s = row.startTime
                                    const e = row.endTime
                                    if (!s && !e)
                                        return "all-day"
                                    if (s && e)
                                        return s + "\n" + e
                                    return s || e
                                }
                                color: DS.Tokens.textSecondary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSizeSm
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        RowLayout {
                            visible: !!row.location
                            Layout.fillWidth: true
                            spacing: 4
                            opacity: ev.past ? 0.85 : 1.0

                            RiceIcon {
                                name: "mark-location"
                                fallback: "network-wireless"
                                implicitSize: 12
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                                tint: DS.Tokens.textIcon
                            }

                            DS.QuietText {
                                text: row.location
                                color: DS.Tokens.textSecondary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSizeSm
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    RiceIcon {
                        id: trashBtn
                        name: "edit-delete"
                        fallback: "user-trash"
                        implicitSize: 14
                        width: 14
                        height: 14
                        visible: !root.isReadOnlyCal(row.calendar)
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        tint: trashMouse.containsMouse ? Theme.error : DS.Tokens.textTertiary
                        opacity: trashMouse.containsMouse ? 1.0 : 0.55
                        scale: trashMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                        }
                        MouseArea {
                            id: trashMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.busy && trashBtn.visible && !row.pending
                            onClicked: root.deleteEvent(row.uid)
                        }
                    }

                    MouseArea {
                        id: evMouse
                        anchors.fill: parent
                        anchors.rightMargin: 36
                        hoverEnabled: true
                        enabled: !row.pending
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openEdit(row.rowObj)
                    }
                    }
                }

                DS.QuietText {
                    anchors.centerIn: parent
                    visible: root.monthLoaded && eventsModel.count === 0
                    text: "No events"
                    color: DS.Tokens.textSecondary
                    font.family: DS.Tokens.fontUi
                    font.pixelSize: DS.Tokens.fontSize
                }
            }

            DS.QuietText {
                visible: root.statusText.length > 0
                text: root.statusText
                color: DS.Tokens.textSecondary
                font.family: DS.Tokens.fontUi
                font.pixelSize: DS.Tokens.fontSizeSm
                Layout.fillWidth: true
            }
            }
        }
    }

    ListModel { id: eventsModel }

    // Blocking readers: first frame after opening already has data.
    FileView {
        id: monthFile
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: calFile
        blockLoading: true
        printErrors: false
    }

    Process {
        id: colorsProc
        command: ["bash", root.script, "calendars"]
        stdout: StdioCollector {
            onStreamFinished: root.applyCalendars(text)
        }
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                const key = root.curKey
                root.curKey = ""
                if (key)
                    root.fetchFinished(key, text)
                Qt.callLater(root.pumpFetch)
            }
        }
        onRunningChanged: if (!running) Qt.callLater(root.pumpFetch)
    }

    Process {
        id: syncProc
        command: ["bash", root.script, "sync"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.statusText = ""
                // The sync may have discovered/removed calendars.
                root.refreshColors()
                root.fetchMonth(root.monthKey(), true)
            }
        }
        onRunningChanged: if (!running) root.busy = false
    }

    Process {
        id: mutProc
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = text.trim().indexOf("ok") >= 0
                const m = root.curMut
                root.curMut = null
                if (ok) {
                    root.statusText = "Synced"
                    if (m) {
                        // Keep the optimistic row until the refetch lands, so it
                        // doesn't blink out and back in.
                        m.done = true
                        root.fetchMonth(m.month, true)
                        const em = m.event ? String(m.event["start-date"]).slice(0, 7) : ""
                        if (em && em !== m.month)
                            root.fetchMonth(em, false)
                    }
                    statusClear.start()
                } else {
                    root.statusText = "Failed"
                    if (m)
                        root.pendingMutations = root.pendingMutations.filter(x => x.id !== m.id)
                    root.render()
                }
            }
        }
        onRunningChanged: if (!running) root.busy = false
    }

    // While panel is open: poll iCloud every 20s and refresh if changed.
    Process {
        id: watchProc
        command: ["bash", root.script, "watch", "20"]
        stdout: SplitParser {
            onRead: chunk => {
                if (String(chunk).indexOf("changed") >= 0) {
                    root.refreshColors()
                    root.fetchMonth(root.monthKey(), true)
                }
            }
        }
    }

    Timer {
        id: statusClear
        interval: 1600
        onTriggered: root.statusText = ""
    }

    Timer {
        interval: 30000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: root.nowTick++
    }
}
