import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "vim"

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
    // list = history; preview = vim text pane
    property string focusPane: "list"
    property string previewFullText: ""
    property bool previewLoading: false
    property string previewDecodeId: ""
    property string previewOriginal: ""
    readonly property bool previewDirty: previewEdit ? (previewEdit.text !== previewOriginal) : false
    readonly property string decodeHelper: Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-decode-text.sh"
    readonly property string storeHelper: Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-store-text.sh"
    // Proxied from shared VimEngine (rice/vim) for UI + host checks
    readonly property string vimMode: vimEngine.mode
    readonly property string vimModeLabel: vimEngine.modeLabel
    readonly property bool visualLinewise: vimEngine.visualLinewise

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
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-clipboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
        searchField.text = ""
        typeFilter = "all"
        filterMenuOpen = false
        markedLines = []
        selectedIndex = 0
        focusPane = "list"
        previewFullText = ""
        vimEngine.reset()
        refreshList()
        openAnim.play()
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
        focusPane = "list"
        previewFullText = ""
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

        // Newest first (cliphist ids grow over time). Mixed text+image by time.
        base.sort((a, b) => (parseInt(b.id, 10) || 0) - (parseInt(a.id, 10) || 0))

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
        selectNewest()
    }

    function rebuildListModel() {
        const rows = []
        // Raycast-style: Today / Yesterday / N days ago / date blocks
        let lastGroup = ""
        for (let i = 0; i < filtered.length; i++) {
            const it = filtered[i]
            const group = it.dayGroup || "Today"
            if (group !== lastGroup) {
                rows.push({ kind: "header", title: group })
                lastGroup = group
            }
            rows.push({ kind: "item", item: it })
        }
        listModel = rows
    }

    function selectNewest() {
        selectedIndex = firstItemIndex()
        // Keep "Today" header in view — anchoring on the first item scrolls it away.
        scrollToTop.restart()
    }

    Timer {
        id: scrollToTop
        interval: 16
        repeat: false
        onTriggered: {
            if (!listView)
                return
            listView.positionViewAtBeginning()
            listView.contentY = 0
        }
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
        if (focusPane === "preview")
            loadPreviewBody()
    }

    function focusListPane() {
        if (focusPane === "preview" && vimMode === "insert" && previewDirty)
            commitPreviewEdit()
        focusPane = "list"
        vimEngine.enterCopy(true)
        searchField.forceActiveFocus()
    }

    function focusPreviewPane() {
        if (!selectedItem || selectedItem.isImage)
            return
        focusPane = "preview"
        vimEngine.enterCopy(false)
        loadPreviewBody()
        Qt.callLater(() => root.placePreviewCursorAtStart())
    }

    function placePreviewCursorAtStart() {
        if (!previewEdit)
            return
        vimEngine.attach(previewEdit, previewFlick)
        previewEdit.forceActiveFocus()
        previewEdit.cursorVisible = vimEngine.isInsert
        if (previewFlick)
            previewFlick.contentY = 0
        vimEngine.enterCopy(false)
        vimEngine.setCursor(0)
    }

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\"'\"'") + "'"
    }

    function storeNewClip(text) {
        if (!text || !String(text).length)
            return
        const q = shQuote(text)
        Quickshell.execDetached([
            "bash", "-lc",
            "printf %s " + q + " | wl-copy; printf %s " + q + " | cliphist store"
        ])
        clipRefreshTimer.restart()
    }

    function commitPreviewEdit() {
        if (!previewEdit)
            return
        const body = previewEdit.text
        if (body === previewOriginal)
            return
        storeNewClip(body)
        previewOriginal = body
        previewFullText = body
    }

    function yankPreviewText(text) {
        if (!text)
            return
        storeNewClip(text)
        vimEngine.enterCopy(true)
    }

    function loadPreviewBody() {
        const it = selectedItem
        previewDecodeId = ""
        previewLoading = false
        if (!it) {
            previewFullText = ""
            previewOriginal = ""
            if (previewEdit)
                previewEdit.text = ""
            return
        }
        if (it.isImage) {
            previewFullText = ""
            previewOriginal = ""
            if (previewEdit)
                previewEdit.text = ""
            return
        }
        const snippet = it.preview || ""
        previewFullText = snippet
        previewOriginal = snippet
        if (previewEdit)
            previewEdit.text = snippet
        if (!it.line)
            return
        previewLoading = true
        previewDecodeId = String(it.id || it.line)
        decodeProc.running = false
        decodeProc.command = ["bash", decodeHelper, it.line]
        decodeProc.running = true
    }

    onSelectedItemChanged: {
        if (focusPane === "preview" && vimMode === "insert" && previewDirty)
            commitPreviewEdit()
        loadPreviewBody()
        if (focusPane === "preview" && (!selectedItem || selectedItem.isImage))
            focusListPane()
        else if (focusPane === "preview")
            Qt.callLater(() => root.placePreviewCursorAtStart())
    }

    function handleVimKey(event) {
        if (!previewEdit)
            return false
        const meta = !!(event.modifiers & Qt.MetaModifier)
        // Super+H → list (physical H via VimKeys)
        if (meta && VimKeys.resolve(event) === "h") {
            focusListPane()
            return true
        }
        if (!vimEngine.editor)
            vimEngine.attach(previewEdit, previewFlick)
        try {
            return vimEngine.handleKey(event)
        } catch (e) {
            console.log("VimEngine.handleKey error:", e)
            return true
        }
    }

    function handleKey(event) {
        if (!root.open)
            return false

        const meta = !!(event.modifiers & Qt.MetaModifier)
        const cmd = VimKeys.resolveShifted(event)

        if (root.filterMenuOpen) {
            if (event.key === Qt.Key_Escape || cmd === "escape") {
                root.closeFilterMenu()
                return true
            }
            if (event.key === Qt.Key_Down || cmd === "j" || cmd === "down") {
                root.moveFilterHighlight(1)
                return true
            }
            if (event.key === Qt.Key_Up || cmd === "k" || cmd === "up") {
                root.moveFilterHighlight(-1)
                return true
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || cmd === "enter") {
                root.applyFilterHighlight()
                return true
            }
            return true
        }

        // Super+H / Super+L — physical keys (works on RU layout)
        if (meta && cmd === "l") {
            root.focusPreviewPane()
            return true
        }
        if (meta && cmd === "h") {
            root.focusListPane()
            return true
        }

        if (root.focusPane === "preview")
            return root.handleVimKey(event)

        if (event.key === Qt.Key_Escape || cmd === "escape") {
            root.close()
            return true
        }
        // j/k — history list (EN + RU). Don't steal letters while filtering text.
        const listNav = searchField.text.length === 0
        if (event.key === Qt.Key_Down || cmd === "down" || (listNav && cmd === "j")) {
            root.moveSelection(1)
            return true
        }
        if (event.key === Qt.Key_Up || cmd === "up" || (listNav && cmd === "k")) {
            root.moveSelection(-1)
            return true
        }
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ShiftModifier)) {
            root.toggleMarkAt(root.selectedIndex)
            return true
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || cmd === "enter") {
            root.activateSelected()
            return true
        }
        return false
    }

    VimEngine {
        id: vimEngine
        onYankRequested: text => root.yankPreviewText(text)
        onCommitRequested: {
            if (root.previewDirty)
                root.commitPreviewEdit()
        }
        onLeaveRequested: root.focusListPane()
        onModeChanged: {
            if (previewEdit)
                previewEdit.cursorVisible = vimEngine.isInsert
            vimEngine.syncBlockCursor()
        }
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

    Timer {
        id: clipRefreshTimer
        interval: 250
        repeat: false
        onTriggered: root.refreshList()
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

    Process {
        id: decodeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const want = root.previewDecodeId
                const it = root.selectedItem
                if (!it || it.isImage)
                    return
                if (want && String(it.id || it.line) !== want)
                    return
                const body = text
                if (body.length > 0) {
                    root.previewFullText = body
                    // Don't clobber in-progress insert edits.
                    if (root.vimMode !== "insert") {
                        root.previewOriginal = body
                        if (previewEdit)
                            previewEdit.text = body
                    }
                }
                root.previewLoading = false
                if (previewFlick)
                    previewFlick.contentY = 0
                if (root.focusPane === "preview" && root.vimMode === "copy")
                    Qt.callLater(() => root.placePreviewCursorAtStart())
            }
        }
        onExited: {
            root.previewLoading = false
            if (root.focusPane === "preview" && root.vimMode === "copy")
                Qt.callLater(() => root.placePreviewCursorAtStart())
        }
    }

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Theme.backdrop
        z: -1
        opacity: 0
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
        transformOrigin: Item.Center
        opacity: 1
        scale: 1

        RiceOpenAnim {
            id: openAnim
            target: panel
            dimTarget: dim
            fromScale: 0.98
        }

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
                        Layout.preferredWidth: filterLabel.implicitWidth + filterHint.implicitWidth + 44
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
                                id: filterHint
                                text: "⌃P"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                opacity: 0.85
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

                // Left list + history depth scrollbar
                Item {
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true

                    ListView {
                        id: listView
                        anchors.fill: parent
                        anchors.rightMargin: listScrollBar.visible ? 10 : 0
                        clip: true
                        spacing: 2
                        model: root.listModel
                        currentIndex: root.selectedIndex
                        // Don't auto-scroll to current item — that hides the Today header above it.
                        highlightFollowsCurrentItem: false
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: modelData.kind === "header" ? 28 : 48

                            Text {
                                visible: modelData.kind === "header"
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.title || ""
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                elide: Text.ElideRight
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
                                opacity: root.focusPane === "preview" ? 0.72 : 1

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
                                        root.focusListPane()
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

                    Item {
                        id: listScrollBar
                        readonly property bool needed: listView.contentHeight > listView.height + 2
                        readonly property real ratio: listView.height / Math.max(1, listView.contentHeight)
                        readonly property real thumbH: Math.max(28, height * ratio)
                        readonly property real maxThumbY: Math.max(0, height - thumbH)
                        readonly property real maxContentY: Math.max(1, listView.contentHeight - listView.height)
                        readonly property real thumbY: maxThumbY * (listView.contentY / maxContentY)

                        visible: needed
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 6

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Theme.borderSubtle
                            opacity: 0.35
                        }

                        Rectangle {
                            id: listScrollThumb
                            width: parent.width
                            height: listScrollBar.thumbH
                            y: listScrollBar.thumbY
                            radius: 3
                            color: Theme.primary
                            opacity: listScrollDrag.active ? 0.95 : 0.65

                            MouseArea {
                                id: listScrollDrag
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                property real grabOffset: 0
                                onPressed: mouse => { grabOffset = mouse.y }
                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return
                                    const localY = listScrollThumb.y + mouse.y - grabOffset
                                    const clamped = Math.max(0, Math.min(listScrollBar.maxThumbY, localY))
                                    listView.contentY = (clamped / Math.max(1, listScrollBar.maxThumbY)) * listScrollBar.maxContentY
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                const target = mouse.y - listScrollBar.thumbH / 2
                                const clamped = Math.max(0, Math.min(listScrollBar.maxThumbY, target))
                                listView.contentY = (clamped / Math.max(1, listScrollBar.maxThumbY)) * listScrollBar.maxContentY
                            }
                        }
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
                        border.width: root.focusPane === "preview" ? 1 : 0
                        border.color: Theme.primary

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

                        // Full text preview — scrollable + selectable
                        Item {
                            anchors.fill: parent
                            visible: root.selectedItem && !root.selectedItem.isImage

                            Flickable {
                                id: previewFlick
                                anchors.fill: parent
                                anchors.margins: 14
                                anchors.rightMargin: previewScrollBar.visible ? 18 : 14
                                contentWidth: width
                                contentHeight: previewEdit.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: true
                                flickableDirection: Flickable.VerticalFlick

                                TextEdit {
                                    id: previewEdit
                                    width: previewFlick.width
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    wrapMode: TextEdit.Wrap
                                    readOnly: !vimEngine.isInsert
                                    selectByMouse: vimEngine.isInsert || vimEngine.isVisual
                                    persistentSelection: true
                                    activeFocusOnPress: true
                                    cursorVisible: activeFocus && vimEngine.isInsert
                                    selectionColor: Theme.primary
                                    selectedTextColor: Theme.textOnAccent

                                    cursorDelegate: Rectangle {
                                        width: 2
                                        color: Theme.primary
                                        visible: previewEdit.activeFocus && vimEngine.isInsert
                                        SequentialAnimation on opacity {
                                            running: previewEdit.activeFocus && vimEngine.isInsert
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 1; to: 0; duration: 530 }
                                            NumberAnimation { from: 0; to: 1; duration: 530 }
                                        }
                                    }

                                    onActiveFocusChanged: {
                                        if (activeFocus) {
                                            root.focusPane = "preview"
                                            if (!vimEngine.editor)
                                                vimEngine.attach(previewEdit, previewFlick)
                                            vimEngine.syncBlockCursor()
                                        }
                                    }

                                    onCursorPositionChanged: {
                                        if (vimEngine.isInsert)
                                            vimEngine.syncBlockCursor()
                                    }

                                    onTextChanged: {
                                        if (root.focusPane === "preview")
                                            Qt.callLater(() => vimEngine.syncBlockCursor())
                                    }

                                    Keys.onPressed: event => {
                                        if (root.handleVimKey(event))
                                            event.accepted = true
                                    }
                                }

                                // Vim block cursor overlay (copy / visual) — tracks visualHead independently of Qt selection end
                                Rectangle {
                                    id: vimBlockCursor
                                    x: vimEngine.blockX
                                    y: vimEngine.blockY
                                    width: vimEngine.blockW
                                    height: vimEngine.blockH
                                    visible: vimEngine.blockVisible && !vimEngine.isInsert
                                    color: Theme.primary
                                    opacity: vimEngine.isVisual ? 0.95 : 0.88
                                    z: 10
                                }
                            }

                            Item {
                                id: previewScrollBar
                                readonly property bool needed: previewFlick.contentHeight > previewFlick.height + 2
                                readonly property real ratio: previewFlick.height / Math.max(1, previewFlick.contentHeight)
                                readonly property real thumbH: Math.max(24, height * ratio)
                                readonly property real maxThumbY: Math.max(0, height - thumbH)
                                readonly property real maxContentY: Math.max(1, previewFlick.contentHeight - previewFlick.height)
                                readonly property real thumbY: maxThumbY * (previewFlick.contentY / maxContentY)

                                visible: needed
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                width: 6

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: Theme.borderSubtle
                                    opacity: 0.35
                                }

                                Rectangle {
                                    id: previewScrollThumb
                                    width: parent.width
                                    height: previewScrollBar.thumbH
                                    y: previewScrollBar.thumbY
                                    radius: 3
                                    color: Theme.primary
                                    opacity: previewScrollDrag.active ? 0.95 : 0.65

                                    MouseArea {
                                        id: previewScrollDrag
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        preventStealing: true
                                        property real grabOffset: 0
                                        onPressed: mouse => { grabOffset = mouse.y }
                                        onPositionChanged: mouse => {
                                            if (!pressed)
                                                return
                                            const localY = previewScrollThumb.y + mouse.y - grabOffset
                                            const clamped = Math.max(0, Math.min(previewScrollBar.maxThumbY, localY))
                                            previewFlick.contentY = (clamped / Math.max(1, previewScrollBar.maxThumbY)) * previewScrollBar.maxContentY
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        const target = mouse.y - previewScrollBar.thumbH / 2
                                        const clamped = Math.max(0, Math.min(previewScrollBar.maxThumbY, target))
                                        previewFlick.contentY = (clamped / Math.max(1, previewScrollBar.maxThumbY)) * previewScrollBar.maxContentY
                                    }
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                visible: root.previewLoading
                                text: "loading…"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
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
                        text: {
                            if (root.filterMenuOpen)
                                return "↑↓/jk filter  ·  ↵ choose  ·  esc close menu"
                            if (root.focusPane === "preview") {
                                const mode = "-- " + root.vimModeLabel + " --"
                                if (root.vimMode === "insert")
                                    return mode + "  ·  esc copy  ·  edits → new clip  ·  Super+H list"
                                if (root.vimMode === "visual")
                                    return mode + "  ·  hjkl move  ·  y yank  ·  /f search  ·  esc copy"
                                if (root.vimMode === "search" || root.vimMode === "findchar")
                                    return mode + "  ·  type…  ·  ↵ go  ·  esc cancel"
                                return mode + "  ·  hjkl  ·  /? nN  ·  fFtT  ·  i insert  ·  v visual  ·  Super+H list"
                            }
                            return "jk list  ·  Super+L preview  ·  ⌃P filter  ·  ⇧↵ mark  ·  ↵ paste"
                        }
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
