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
        const first = new Date(viewYear, viewMonth, 1)
        const start = (first.getDay() + 6) % 7
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        const today = new Date()
        const isCurrentMonth = today.getFullYear() === viewYear && today.getMonth() === viewMonth
        const cells = []
        for (let i = 0; i < start; i++)
            cells.push({ day: 0, today: false })
        for (let d = 1; d <= daysInMonth; d++)
            cells.push({ day: d, today: isCurrentMonth && d === today.getDate() })
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
        const v = root.eventDays[String(day)]
        return Array.isArray(v) ? v : []
    }

    function refreshColors() {
        colorsProc.running = true
    }

    function refreshMonth() {
        daysProc.command = ["bash", root.script, "days", root.monthKey()]
        daysProc.running = true
        refreshEvents()
    }

    function refreshEvents() {
        eventsProc.command = ["bash", root.script, "events", root.selectedIso()]
        eventsProc.running = true
    }

    function syncAndRefresh() {
        busy = true
        statusText = "Syncing…"
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
            OverlayHub.closeAll()
            refreshColors()
            syncAndRefresh()
            watchProc.running = true
            Qt.callLater(() => panel.forceActiveFocus())
        } else {
            closeForm()
            statusText = ""
            watchProc.running = false
        }
    }

    onSelectedDayChanged: {
        if (open && !formOpen)
            refreshEvents()
    }

    visible: open
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
        color: Theme.background
        radius: Theme.radiusLg
        border.width: 1
        border.color: Theme.borderSubtle
        focus: root.open
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.formOpen)
                    root.closeForm()
                else
                    root.close()
                event.accepted = true
            }
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
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    RiceIcon {
                        name: "go-previous"
                        fallback: "arrow-left"
                        implicitSize: 16
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
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
                    }

                    RiceIcon {
                        name: "go-next"
                        fallback: "arrow-right"
                        implicitSize: 16
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    // Identical hit-boxes + glyph size so refresh / add / close match.
                    Repeater {
                        model: [
                            { glyph: "↻", action: "sync" },
                            { glyph: "+", action: "add" },
                            { glyph: "×", action: "close" }
                        ]

                        Item {
                            required property var modelData
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            opacity: modelData.action === "sync" && root.busy ? 0.4 : 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.glyph
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !(modelData.action === "sync" && root.busy)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.action === "sync")
                                        root.syncAndRefresh()
                                    else if (modelData.action === "add")
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
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        visible: modelData.day > 0

                        readonly property bool selected: modelData.day === root.selectedDay
                        readonly property var cals: root.dayCals(modelData.day)

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -3
                            width: 28
                            height: 28
                            radius: 14
                            color: cell.selected ? Theme.text : (modelData.today ? Theme.primary : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: cell.modelData.day > 0 ? String(cell.modelData.day) : ""
                                color: cell.selected
                                    ? Theme.background
                                    : (cell.modelData.today ? Theme.textOnAccent : Theme.text)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: cell.selected || cell.modelData.today
                            }
                        }

                        // Apple-style colored dots / split capsule
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            spacing: cell.cals.length > 2 ? 1 : 2
                            visible: cell.cals.length > 0

                            Repeater {
                                model: cell.cals.slice(0, 3)

                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: cell.cals.length === 1 ? 6 : (cell.cals.length === 2 ? 7 : 5)
                                    height: cell.cals.length === 1 ? 6 : 5
                                    radius: height / 2
                                    color: root.calAccent(modelData)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
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
                color: Theme.borderSubtle
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
                    visible: !root.formOpen
                    radius: Theme.radiusSm
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.borderSubtle
                    implicitWidth: todayLbl.implicitWidth + 16
                    implicitHeight: 24

                    Text {
                        id: todayLbl
                        anchors.centerIn: parent
                        text: "Today"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }

                    MouseArea {
                        anchors.fill: parent
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
                            color: Theme.surfaceContainer
                            border.width: 1
                            border.color: titleInput.activeFocus ? Theme.primary : Theme.borderSubtle

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
                                color: root.draftAllDay ? Theme.primary : Theme.surfaceContainer
                                border.width: 1
                                border.color: root.draftAllDay ? Theme.primary : Theme.borderSubtle

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: root.draftAllDay ? parent.width - width - 3 : 3
                                    color: Theme.text
                                    Behavior on x { NumberAnimation { duration: 120 } }
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
                            color: Theme.surfaceContainer
                            border.width: 1
                            border.color: Theme.borderSubtle

                            TextInput {
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
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: Theme.radiusSm
                                    color: root.draftCalendar === modelData.id
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                                        : Theme.surfaceContainer
                                    border.width: 1
                                    border.color: root.draftCalendar === modelData.id ? Theme.primary : Theme.borderSubtle

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
                                        anchors.fill: parent
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
                    visible: root.formEditing
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: Theme.radiusSm
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)
                    border.width: 1
                    border.color: Theme.error
                    opacity: root.busy ? 0.5 : 1

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
                        anchors.fill: parent
                        enabled: !root.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteCurrent()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radiusSm
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.borderSubtle

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeForm()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radiusSm
                        color: Theme.primary
                        opacity: root.busy ? 0.5 : 1

                        Text {
                            anchors.centerIn: parent
                            text: root.formEditing ? "Save" : "Add"
                            color: Theme.textOnAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
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
                    width: ListView.view.width
                    height: Math.max(evCol.implicitHeight + 14, 44)
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.borderSubtle
                    opacity: past ? 0.42 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 180 } }

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
                        opacity: 0.55
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.busy
                            onClicked: root.deleteEvent(ev.modelData.uid || "")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: 36
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
                    const obj = JSON.parse(text.trim() || "{}")
                    root.eventDays = obj && typeof obj === "object" ? obj : {}
                } catch (e) {
                    root.eventDays = {}
                }
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
