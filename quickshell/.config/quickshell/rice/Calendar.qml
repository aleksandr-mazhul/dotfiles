pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property int selectedDay: new Date().getDate()
    property var eventDays: ({}) // { "1": ["work","home"], ... }
    property int eventDaysRev: 0
    property var events: []
    property var calColors: ({
        home: "#34AADC",
        work: "#CB30E0",
        uni: "#0088FF",
        reminders: "#B14BC9"
    })

    property bool formOpen: false
    property bool formEditing: false
    property string editUid: ""
    property bool busy: false
    property string statusText: ""

    property string draftTitle: ""
    property string draftLocation: ""
    property string draftCalendar: "home"
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
        // Depend on eventDaysRev so the grid rebuilds when markers arrive.
        void root.eventDaysRev
        const first = new Date(viewYear, viewMonth, 1)
        const start = (first.getDay() + 6) % 7
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        const today = new Date()
        const isCurrentMonth = today.getFullYear() === viewYear && today.getMonth() === viewMonth
        const cells = []
        for (let i = 0; i < start; i++)
            cells.push({ day: 0, today: false, cals: [] })
        for (let d = 1; d <= daysInMonth; d++) {
            const key = String(d)
            const raw = root.eventDays ? root.eventDays[key] : null
            const cals = Array.isArray(raw) ? raw.slice(0, 3) : []
            cells.push({
                day: d,
                today: isCurrentMonth && d === today.getDate(),
                cals: cals
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
        refreshMonth()
    }

    function goToday() {
        const now = new Date()
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
        selectedDay = now.getDate()
        formOpen = false
        refreshMonth()
    }

    function calAccent(name) {
        return root.calColors[name] || Theme.primary
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
        return Array.isArray(v) ? v : []
    }

    function refreshColors() {
        colorsProc.running = false
        colorsProc.running = true
    }

    function refreshMonth() {
        daysProc.running = false
        daysProc.command = ["bash", root.script, "days", root.monthKey()]
        daysProc.running = true
        refreshEvents()
    }

    function refreshEvents() {
        eventsProc.running = false
        eventsProc.command = ["bash", root.script, "events", root.selectedIso()]
        eventsProc.running = true
    }

    function syncAndRefresh() {
        busy = true
        statusText = "Syncing…"
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
        draftCalendar = "home"
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

    function openEdit(ev) {
        formEditing = true
        editUid = ev.uid || ""
        draftTitle = ev.title || ""
        draftLocation = ev.location || ""
        draftCalendar = ev.calendar || "home"
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
        const cal = draftCalendar || "home"
        const start = draftAllDay ? "allday" : timeStr(draftStartH, draftStartM)
        const end = draftAllDay ? "allday" : timeStr(draftEndH, draftEndM)
        busy = true
        statusText = "Saving…"
        if (formEditing && editUid) {
            mutProc.command = [
                "bash", root.script, "edit",
                editUid, root.selectedIso(), start, end, title, loc, cal
            ]
        } else {
            mutProc.command = [
                "bash", root.script, "add",
                root.selectedIso(), start, end, title, loc, cal
            ]
        }
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
        busy = true
        statusText = "Deleting…"
        mutProc.command = ["bash", root.script, "delete", uid]
        mutProc.running = true
    }

    function toggle() { open = !open }
    function show() { open = true }
    function close() {
        open = false
        closeForm()
        watchProc.running = false
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop()
            OverlayHub.closeAll()
            refreshColors()
            // Local markers first, then sync pulls remote updates.
            refreshMonth()
            syncAndRefresh()
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
            refreshEvents()
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

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Theme.glassBackground
        radius: Theme.radiusLg
        border.width: 1
        border.color: Theme.glassBorder
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

        // Soft inner highlight — Apple-like glass edge without heavy chrome
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radiusLg - 1
            color: "transparent"
            border.width: 1
            border.color: Theme.glassBorderSubtle
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
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
                        radius: 8
                        color: prevMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }

                        RiceIcon {
                            anchors.centerIn: parent
                            customSource: Qt.resolvedUrl("assets/chevron-left.svg")
                            tint: prevMouse.containsMouse ? Theme.text : Theme.textMuted
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

                    Text {
                        text: root.monthNames[root.viewMonth] + " " + root.viewYear
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                    }

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 8
                        color: nextMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }

                        RiceIcon {
                            anchors.centerIn: parent
                            customSource: Qt.resolvedUrl("assets/chevron-right.svg")
                            tint: nextMouse.containsMouse ? Theme.text : Theme.textMuted
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
                            radius: 8
                            color: hdrBtn.hovered ? Theme.glassSurfaceHover : "transparent"
                            opacity: hdrBtn.modelData.action === "sync" && root.busy ? 0.4 : 1
                            Behavior on color {
                                ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: hdrBtn.modelData.action !== "close"
                                text: hdrBtn.modelData.glyph
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.bold: true
                            }

                            RiceIcon {
                                anchors.centerIn: parent
                                visible: hdrBtn.modelData.action === "close"
                                customSource: Qt.resolvedUrl("assets/close.svg")
                                tint: hdrBtn.hovered ? Theme.text : Theme.textMuted
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
                    Text {
                        required property string modelData
                        text: modelData
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
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
                        readonly property var cals: {
                            if (cell.isPad)
                                return []
                            // Prefer baked-in model data; fall back to live map.
                            const baked = modelData.cals
                            if (Array.isArray(baked) && baked.length)
                                return baked
                            return root.dayCals(modelData.day)
                        }

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
                                    return Theme.text
                                if (modelData.today)
                                    return cell.hovered ? Theme.glassTileActiveHover : Theme.glassTileActive
                                return cell.hovered ? Theme.glassSurfaceHover : "transparent"
                            }
                            border.width: modelData.today && !cell.selected ? 1 : 0
                            border.color: Theme.glassTileBorder
                            Behavior on color {
                                ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: cell.isPad ? "" : String(cell.modelData.day)
                                color: cell.selected
                                    ? Theme.background
                                    : (cell.modelData.today ? Theme.primary : Theme.text)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: cell.selected || cell.modelData.today
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
                                root.refreshEvents()
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: !root.formOpen
                Layout.fillWidth: true
                height: 1
                color: Theme.glassBorderSubtle
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: {
                        const d = new Date(root.viewYear, root.viewMonth, root.selectedDay)
                        const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                        return days[d.getDay()] + " · " + root.selectedDay
                    }
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: todayBtn
                    visible: !root.formOpen
                    property bool hovered: todayMouse.containsMouse
                    radius: Theme.radiusSm
                    color: todayBtn.hovered ? Theme.glassSurfaceHover : Theme.glassSurface
                    border.width: 1
                    border.color: Theme.glassBorderSubtle
                    implicitWidth: todayLbl.implicitWidth + 16
                    implicitHeight: 24
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }

                    Text {
                        id: todayLbl
                        anchors.centerIn: parent
                        text: "Today"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
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

                Text {
                    text: root.formEditing ? "Edit event" : "New event"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
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
                            radius: Theme.radiusSm
                            color: Theme.glassSurface
                            border.width: 1
                            border.color: titleInput.activeFocus ? Theme.primary : Theme.glassBorderSubtle
                            Behavior on border.color {
                                ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                            }

                            TextInput {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                text: root.draftTitle
                                onTextChanged: root.draftTitle = text
                                Keys.onReturnPressed: root.submitForm()

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Title"
                                    color: Theme.textMuted
                                    font: titleInput.font
                                    visible: titleInput.text.length === 0
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "All-day"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 42
                                height: 24
                                radius: 12
                                color: root.draftAllDay ? Theme.primary : Theme.glassSurface
                                border.width: 1
                                border.color: root.draftAllDay ? Theme.primary : Theme.glassBorderSubtle
                                Behavior on color {
                                    ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: root.draftAllDay ? parent.width - width - 3 : 3
                                    color: Theme.text
                                    Behavior on x {
                                        NumberAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
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
                            radius: Theme.radiusSm
                            color: Theme.glassSurface
                            border.width: 1
                            border.color: locationInput.activeFocus ? Theme.primary : Theme.glassBorderSubtle
                            Behavior on border.color {
                                ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                            }

                            TextInput {
                                id: locationInput
                                anchors.fill: parent
                                anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                text: root.draftLocation
                                onTextChanged: root.draftLocation = text

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Location (optional)"
                                    color: Theme.textMuted
                                    font: parent.font
                                    visible: parent.text.length === 0
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { id: "home", label: "Home" },
                                    { id: "work", label: "Work" },
                                    { id: "uni", label: "Uni" }
                                ]

                                Rectangle {
                                    id: calChip
                                    required property var modelData
                                    property bool hovered: chipMouse.containsMouse
                                    readonly property bool active: root.draftCalendar === calChip.modelData.id
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: Theme.radiusSm
                                    color: {
                                        if (calChip.active)
                                            return calChip.hovered ? Theme.glassTileActiveHover : Theme.glassTileActive
                                        return calChip.hovered ? Theme.glassSurfaceHover : Theme.glassSurface
                                    }
                                    border.width: 1
                                    border.color: calChip.active ? Theme.glassTileBorder : Theme.glassBorderSubtle
                                    Behavior on color {
                                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
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
                                        Text {
                                            text: modelData.label
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                        }
                                    }

                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
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
                    radius: Theme.radiusSm
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, deleteBtn.hovered ? 0.22 : 0.15)
                    border.width: 1
                    border.color: Theme.error
                    opacity: root.busy ? 0.5 : 1
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
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
                        Text {
                            text: "Delete event"
                            color: Theme.error
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
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
                        radius: Theme.radiusSm
                        color: cancelBtn.hovered ? Theme.glassSurfaceHover : Theme.glassSurface
                        border.width: 1
                        border.color: Theme.glassBorderSubtle
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
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
                        radius: Theme.radiusSm
                        color: Theme.primary
                        opacity: root.busy ? 0.5 : (submitBtn.hovered ? 0.88 : 1)
                        Behavior on opacity {
                            NumberAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.formEditing ? "Save" : "Add"
                            color: Theme.textOnAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
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
                model: root.events

                delegate: Rectangle {
                    id: ev
                    required property var modelData
                    readonly property bool past: root.isEventPast(modelData)
                    readonly property bool hovered: evMouse.containsMouse
                    width: ListView.view.width
                    height: Math.max(evCol.implicitHeight + 14, 44)
                    radius: Theme.radiusMd
                    color: ev.hovered ? Theme.glassSurfaceHover : Theme.glassSurface
                    border.width: 1
                    border.color: Theme.glassBorderSubtle
                    opacity: past ? 0.42 : 1.0
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: 3
                        radius: 1.5
                        color: root.calAccent(ev.modelData.calendar || "")
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

                            Text {
                                text: ev.modelData.title || "Event"
                                color: ev.past ? Theme.textMuted : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: !ev.past
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    const s = ev.modelData["start-time"] || ""
                                    const e = ev.modelData["end-time"] || ""
                                    if (!s && !e)
                                        return "all-day"
                                    if (s && e)
                                        return s + "\n" + e
                                    return s || e
                                }
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        RowLayout {
                            visible: !!(ev.modelData.location && ev.modelData.location.length)
                            Layout.fillWidth: true
                            spacing: 4
                            opacity: ev.past ? 0.85 : 1.0

                            RiceIcon {
                                name: "mark-location"
                                fallback: "network-wireless"
                                implicitSize: 12
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                            }

                            Text {
                                text: ev.modelData.location || ""
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
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
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        tint: trashMouse.containsMouse ? Theme.error : Theme.textMuted
                        opacity: trashMouse.containsMouse ? 1.0 : 0.55
                        scale: trashMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }
                        MouseArea {
                            id: trashMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.busy
                            onClicked: root.deleteEvent(ev.modelData.uid || "")
                        }
                    }

                    MouseArea {
                        id: evMouse
                        anchors.fill: parent
                        anchors.rightMargin: 36
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openEdit(ev.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.events.length === 0 && !root.busy
                    text: "No events"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            Text {
                visible: root.statusText.length > 0
                text: root.statusText
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                Layout.fillWidth: true
            }
        }
    }

    Process {
        id: colorsProc
        command: ["bash", root.script, "colors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(text.trim())
                    if (obj && typeof obj === "object")
                        root.calColors = obj
                } catch (e) {}
            }
        }
    }

    Process {
        id: daysProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = text.trim()
                    // Tolerate any noise before/after the JSON object.
                    const start = raw.indexOf("{")
                    const end = raw.lastIndexOf("}")
                    const slice = (start >= 0 && end > start) ? raw.slice(start, end + 1) : "{}"
                    const obj = JSON.parse(slice)
                    root.eventDays = obj && typeof obj === "object" ? obj : {}
                } catch (e) {
                    root.eventDays = {}
                }
                root.eventDaysRev++
            }
        }
    }

    Process {
        id: eventsProc
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    if (!line)
                        return
                    try { rows.push(JSON.parse(line)) } catch (e) {}
                })
                root.events = rows
            }
        }
    }

    Process {
        id: syncProc
        command: ["bash", root.script, "sync"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.statusText = ""
                root.refreshMonth()
            }
        }
        onRunningChanged: if (!running) root.busy = false
    }

    Process {
        id: mutProc
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = text.trim().indexOf("ok") >= 0
                if (ok) {
                    root.closeForm()
                    root.statusText = "Synced"
                    root.refreshMonth()
                    statusClear.start()
                } else {
                    root.statusText = "Failed"
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
                if (String(chunk).indexOf("changed") >= 0)
                    root.refreshMonth()
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
