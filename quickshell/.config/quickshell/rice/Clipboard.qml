import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Raycast-inspired clipboard history: fixed size, list + preview/info, type filter.
PanelWindow {
    id: root

    property bool open: false
    property var items: []
    property var filtered: []
    property var listModel: []
    property var markedLines: []
    property string prevAddr: ""
    property string typeFilter: "all" // all | image | text
    property int selectedIndex: 0
    property bool filterMenuOpen: false
    property int filterHighlight: 0
    property bool pendingOpenFilter: false

    readonly property var filterOptions: [
        { value: "all", label: "All Types" },
        { value: "image", label: "Images" },
        { value: "text", label: "Text" }
    ]

    readonly property var selectedItem: {
        if (!listModel || selectedIndex < 0 || selectedIndex >= listModel.length)
            return null
        const row = listModel[selectedIndex]
        return row && row.kind === "item" ? row.item : null
    }

    visible: open
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    Component.onCompleted: OverlayHub.register(root)

    function toggle() {
        if (open)
            close()
        else
            show()
    }

    function show() {
        OverlayHub.closeOthers(root)
        open = true
        selectedIndex = 0
        searchField.text = ""
        typeFilter = "all"
        filterMenuOpen = false
        markedLines = []
        refreshList()
        Qt.callLater(() => {
            if (pendingOpenFilter) {
                pendingOpenFilter = false
                openFilterMenu()
            } else {
                searchField.forceActiveFocus()
            }
        })
    }

    function close() {
        if (!open)
            return
        open = false
        searchField.text = ""
        filterMenuOpen = false
        pendingOpenFilter = false
        markedLines = []
    }

    function showFilter() {
        if (open) {
            toggleFilterMenu()
            return
        }
        pendingOpenFilter = true
        show()
    }

    function toggleFilter() {
        showFilter()
    }

    function openFilter() {
        showFilter()
    }

    function syncFilterHighlight() {
        let idx = 0
        for (let i = 0; i < filterOptions.length; i++) {
            if (filterOptions[i].value === typeFilter) {
                idx = i
                break
            }
        }
        filterHighlight = idx
    }

    function openFilterMenu() {
        syncFilterHighlight()
        filterMenuOpen = true
        searchField.forceActiveFocus()
    }

    function closeFilterMenu() {
        filterMenuOpen = false
        searchField.forceActiveFocus()
    }

    function toggleFilterMenu() {
        if (filterMenuOpen)
            closeFilterMenu()
        else
            openFilterMenu()
    }

    function moveFilterHighlight(delta) {
        const n = filterOptions.length
        filterHighlight = (filterHighlight + delta + n) % n
    }

    function applyFilterHighlight() {
        if (filterHighlight < 0 || filterHighlight >= filterOptions.length)
            return
        setTypeFilter(filterOptions[filterHighlight].value)
    }

    function refreshList() {
        captureFocus.running = true
        indexProc.running = true
    }

    function applyFilter() {
        const q = searchField.text.trim().toLowerCase()
        let base = items.slice()
        if (typeFilter === "image")
            base = base.filter(it => it.isImage)
        else if (typeFilter === "text")
            base = base.filter(it => !it.isImage)

        if (q) {
            base = base.filter(it => {
                const hay = ((it.label || "") + " " + (it.preview || "") + " " + (it.dimsLabel || "")).toLowerCase()
                return hay.includes(q)
            })
        }

        filtered = base
        rebuildListModel()
        clampSelection()
    }

    function rebuildListModel() {
        const rows = []
        let lastGroup = ""
        for (let i = 0; i < filtered.length; i++) {
            const it = filtered[i]
            const group = it.dayGroup || "Recent"
            if (group !== lastGroup) {
                rows.push({ kind: "header", title: group })
                lastGroup = group
            }
            rows.push({ kind: "item", item: it })
        }
        listModel = rows
        // Keep selection on first item row
        if (selectedIndex >= listModel.length || selectedIndex < 0 || (listModel[selectedIndex] && listModel[selectedIndex].kind !== "item"))
            selectedIndex = firstItemIndex()
    }

    function firstItemIndex() {
        for (let i = 0; i < listModel.length; i++) {
            if (listModel[i].kind === "item")
                return i
        }
        return 0
    }

    function clampSelection() {
        if (!listModel || listModel.length === 0) {
            selectedIndex = 0
            return
        }
        if (selectedIndex >= listModel.length)
            selectedIndex = listModel.length - 1
        if (selectedIndex < 0)
            selectedIndex = 0
        if (listModel[selectedIndex] && listModel[selectedIndex].kind !== "item")
            selectedIndex = nextItemIndex(selectedIndex, 1)
    }

    function nextItemIndex(from, delta) {
        if (!listModel || listModel.length === 0)
            return 0
        let i = from
        for (let n = 0; n < listModel.length; n++) {
            i = (i + delta + listModel.length) % listModel.length
            if (listModel[i].kind === "item")
                return i
        }
        return from
    }

    function moveSelection(delta) {
        if (!listModel || listModel.length === 0)
            return
        selectedIndex = nextItemIndex(selectedIndex, delta)
        listView.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function isMarked(item) {
        if (!item || !item.line)
            return false
        return markedLines.indexOf(item.line) >= 0
    }

    function toggleMarkAt(index) {
        if (!listModel || index < 0 || index >= listModel.length)
            return
        const row = listModel[index]
        if (!row || row.kind !== "item")
            return
        const item = row.item
        if (!item || !item.isImage || !item.line)
            return
        const line = item.line
        const idx = markedLines.indexOf(line)
        let next
        if (idx >= 0) {
            next = markedLines.slice()
            next.splice(idx, 1)
        } else {
            next = markedLines.concat([line])
        }
        markedLines = next
    }

    function activateSelected() {
        if (markedLines.length > 0) {
            pasteBatch(markedLines.slice())
            return
        }
        pasteItem(selectedItem)
    }

    function pasteItem(item) {
        if (!item)
            return
        pasteProc.exec([
            "bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-paste-from-line.sh",
            item.line,
            prevAddr
        ])
        close()
    }

    function pasteBatch(lines) {
        if (!lines || lines.length === 0)
            return
        const addr = prevAddr
        close()
        const args = [
            "bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-paste-batch.sh",
            addr
        ].concat(lines)
        pasteProc.exec(args)
    }

    function setTypeFilter(value) {
        typeFilter = value
        filterMenuOpen = false
        applyFilter()
        selectedIndex = firstItemIndex()
        listView.positionViewAtIndex(selectedIndex, ListView.Beginning)
        searchField.forceActiveFocus()
    }

    function filterLabel() {
        if (typeFilter === "image")
            return "Images"
        if (typeFilter === "text")
            return "Text"
        return "All Types"
    }

    function thumbUrl(item) {
        if (!item || !item.isImage)
            return ""
        const path = item.thumb || item.previewPath || ""
        return path ? ("file://" + path) : ""
    }

    function previewUrl(item) {
        if (!item || !item.isImage)
            return ""
        const path = item.previewPath || item.thumb || ""
        return path ? ("file://" + path) : ""
    }

    function handleKey(event) {
        if (!root.open)
            return false

        if (root.filterMenuOpen) {
            if (event.key === Qt.Key_Escape) {
                root.closeFilterMenu()
                return true
            }
            if (event.key === Qt.Key_Down) {
                root.moveFilterHighlight(1)
                return true
            }
            if (event.key === Qt.Key_Up) {
                root.moveFilterHighlight(-1)
                return true
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.applyFilterHighlight()
                return true
            }
            return true
        }

        if (event.key === Qt.Key_Escape) {
            root.close()
            return true
        }
        if (event.key === Qt.Key_Down) {
            root.moveSelection(1)
            return true
        }
        if (event.key === Qt.Key_Up) {
            root.moveSelection(-1)
            return true
        }
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ShiftModifier)) {
            root.toggleMarkAt(root.selectedIndex)
            return true
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateSelected()
            return true
        }
        return false
    }

    Process {
        id: captureFocus
        command: ["bash", "-c", "hyprctl activewindow -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(\"address\",\"\"))'"]
        stdout: StdioCollector {
            onStreamFinished: root.prevAddr = text.trim()
        }
    }

    Process {
        id: indexProc
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-index.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.items = data.items || []
                } catch (e) {
                    root.items = []
                }
                root.applyFilter()
            }
        }
    }

    Process { id: pasteProc }

    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop
        z: -1
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: panel
        width: Theme.clipboardWidth
        height: Theme.clipboardHeight
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        clip: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radiusLg - 1
            color: "transparent"
            border.width: 1
            border.color: Theme.borderSubtle
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header: search + type filter
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusMd
                        color: Theme.surfaceContainer
                        border.color: searchField.activeFocus && !root.filterMenuOpen ? Theme.primary : Theme.borderSubtle
                        border.width: 1

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            clip: true
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.textOnAccent

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Type to filter entries…"
                                color: Theme.textMuted
                                font: searchField.font
                                visible: searchField.text.length === 0
                            }

                            onTextChanged: root.applyFilter()

                            Keys.onPressed: event => {
                                if (root.handleKey(event))
                                    event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        id: filterPill
                        Layout.preferredWidth: filterLabel.implicitWidth + 36
                        Layout.fillHeight: true
                        radius: height / 2
                        color: Theme.surfaceContainer
                        border.color: root.filterMenuOpen ? Theme.primary : Theme.borderSubtle
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                id: filterLabel
                                text: root.filterLabel()
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                            }
                            Text {
                                text: "▾"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSizeSm
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleFilterMenu()
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.borderSubtle
                }
            }

            // Body: list + preview
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Left list
                ListView {
                    id: listView
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: root.listModel
                    currentIndex: root.selectedIndex
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: modelData.kind === "header" ? 28 : 48

                        Text {
                            visible: modelData.kind === "header"
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title || ""
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                        }

                        Rectangle {
                            visible: modelData.kind === "item"
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            radius: Theme.radiusSm
                            color: {
                                if (index === root.selectedIndex)
                                    return Theme.rowSelected
                                if (rowMouse.containsMouse)
                                    return Theme.rowHover
                                return "transparent"
                            }
                            border.width: modelData.item && root.isMarked(modelData.item) ? 2 : 0
                            border.color: Theme.secondary

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: 6
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        visible: !!(modelData.item && modelData.item.isImage)
                                        source: modelData.item ? root.thumbUrl(modelData.item) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !(modelData.item && modelData.item.isImage)
                                        text: "Aa"
                                        color: index === root.selectedIndex ? Theme.textOnAccent : Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Rectangle {
                                        visible: !!(modelData.item && root.isMarked(modelData.item))
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 1
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: Theme.secondary

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: Theme.textOnAccent
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.item ? (modelData.item.label || "") : ""
                                    color: index === root.selectedIndex ? Theme.textOnAccent : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onEntered: root.selectedIndex = index
                                onClicked: mouse => {
                                    root.selectedIndex = index
                                    if (mouse.modifiers & Qt.ShiftModifier || mouse.button === Qt.RightButton)
                                        root.toggleMarkAt(index)
                                }
                                onDoubleClicked: {
                                    root.selectedIndex = index
                                    root.activateSelected()
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.filtered || root.filtered.length === 0
                        text: "Nothing found"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Theme.borderSubtle
                }

                // Right preview + info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.surfaceContainer
                        clip: true

                        // Image preview
                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: 18
                            visible: root.selectedItem && root.selectedItem.isImage
                            source: root.selectedItem ? root.previewUrl(root.selectedItem) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                        }

                        // Text preview
                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 18
                            visible: root.selectedItem && !root.selectedItem.isImage
                            contentWidth: width
                            contentHeight: previewText.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: previewText
                                width: parent.width
                                text: root.selectedItem ? (root.selectedItem.preview || "") : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                wrapMode: Text.Wrap
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.selectedItem
                            text: "Select an entry"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: infoCol.implicitHeight + 28
                        color: Theme.surface

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 1
                            color: Theme.borderSubtle
                        }

                        ColumnLayout {
                            id: infoCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 10

                            Text {
                                text: "Information"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Content type"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    Layout.preferredWidth: 110
                                }
                                Text {
                                    text: root.selectedItem ? (root.selectedItem.contentType || "") : "—"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: !!(root.selectedItem && root.selectedItem.isImage && root.selectedItem.dimsLabel)
                                Text {
                                    text: "Dimensions"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    Layout.preferredWidth: 110
                                }
                                Text {
                                    text: root.selectedItem ? (root.selectedItem.dimsLabel || "") : ""
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: !!(root.selectedItem && root.selectedItem.isImage && root.selectedItem.mtimeLabel)
                                Text {
                                    text: "Created"
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    Layout.preferredWidth: 110
                                }
                                Text {
                                    text: root.selectedItem ? (root.selectedItem.mtimeLabel || "") : ""
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            // Footer
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Theme.borderSubtle
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    Text {
                        text: root.markedLines.length > 0
                            ? ("Clipboard · " + root.markedLines.length + " marked")
                            : "Clipboard History"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.filterMenuOpen
                            ? "↑↓ filter  ·  ↵ choose  ·  esc close menu"
                            : "⇧↵ mark  ·  ↵ paste  ·  esc close"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }
                }
            }
        }

        // Type filter dropdown
        Rectangle {
            visible: root.filterMenuOpen
            width: 160
            height: filterCol.implicitHeight + 12
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 54
            anchors.rightMargin: 14
            radius: Theme.radiusMd
            color: Theme.surfaceContainer
            border.color: Theme.border
            border.width: 1
            z: 30

            ColumnLayout {
                id: filterCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: root.filterOptions

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        height: 34
                        radius: Theme.radiusSm
                        color: {
                            if (index === root.filterHighlight)
                                return Theme.rowSelected
                            if (modelData.value === root.typeFilter)
                                return Theme.rowHover
                            return "transparent"
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: index === root.filterHighlight ? Theme.textOnAccent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.filterHighlight = index
                            onClicked: {
                                root.filterHighlight = index
                                root.applyFilterHighlight()
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.filterMenuOpen
            z: 20
            onClicked: root.closeFilterMenu()
        }
    }
}
