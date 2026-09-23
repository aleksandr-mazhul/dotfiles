import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "vim"
import "ds" as DS

// Clipboard history as a launcher page (same window as SearchListPopup).
Item {
    id: root

    property var host: null
    readonly property bool open: !!(host && host.open && visible)
    property var items: []
    property var filtered: []
    property var listModel: []
    property var markedLines: []
    property string prevAddr: ""
    property string typeFilter: "all" // all | image | text
    property int selectedIndex: 0
    property bool filterMenuOpen: false
    property int filterHighlight: 0
    property bool keyboardNav: false
    property point navPointer: Qt.point(-1, -1)
    // While true, list rebuilds (index/cache) always land on the newest item.
    property bool pinNewest: false
    // list = history; preview = text pane (Super+L / Super+H)
    property string focusPane: "list"
    property string previewFullText: ""
    property bool previewLoading: false
    property string previewDecodeId: ""
    property string previewOriginal: ""
    readonly property string decodeHelper: Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-decode-text.sh"
    readonly property string indexHelper: Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-index.sh"
    property bool liveIndexReady: false

    readonly property var filterOptions: [
        { value: "all", label: "All" },
        { value: "image", label: "Images" },
        { value: "text", label: "Text" }
    ]
    readonly property string typeFilterLabel: typeFilter === "image"
        ? "Images"
        : (typeFilter === "text" ? "Text" : "All")
    readonly property string pasteHintLabel: markedLines.length > 0
        ? ("Paste " + markedLines.length)
        : "Paste"
    readonly property string previewMeta: {
        const it = selectedItem
        if (!it)
            return ""
        const bits = []
        if (it.contentType)
            bits.push(it.contentType)
        if (it.isImage && it.dimsLabel)
            bits.push(it.dimsLabel)
        if (it.sizeLabel)
            bits.push(it.sizeLabel)
        if (it.mtimeLabel)
            bits.push(it.mtimeLabel)
        return bits.join(" · ")
    }
    readonly property bool selectedIsCode: root.looksLikeCode(selectedItem)
    // Same plate as launcher home: 960 × search + 8 rows + footer.
    readonly property int paneHeight: {
        const t = DS.Tokens
        return t.paddingSurface * 2 + t.searchFieldHeight + 8
            + 8 * t.rowHeight + 8 + t.footerHeight
    }
    readonly property int listWidth: Math.max(280, Math.round((width > 1 ? width : 960) * 0.38))

    readonly property var selectedItem: {
        if (!listModel || selectedIndex < 0 || selectedIndex >= listModel.length)
            return null
        const row = listModel[selectedIndex]
        return row && row.kind === "item" ? row.item : null
    }

    width: parent ? parent.width : 960
    implicitWidth: width
    implicitHeight: paneHeight
    visible: false

    Keys.onPressed: event => {
        if (searchField && searchField.activeFocus)
            return
        if (previewEdit && previewEdit.activeFocus)
            return
        if (root.handleKey(event))
            event.accepted = true
    }

    Component.onCompleted: cacheProc.running = true

    property alias searchField: searchFieldBox.input
    property string pageId: "clipboard"

    function enter() {
        DS.AdaptiveContrast.refresh()
        searchField.text = ""
        typeFilter = "all"
        filterMenuOpen = false
        markedLines = []
        selectedIndex = 0
        focusPane = "list"
        previewFullText = ""
        keyboardNav = true
        navPointer = Qt.point(-1, -1)
        pinNewest = true
        if (items && items.length)
            applyFilter()
        refreshList()
        Qt.callLater(() => {
            if (root.pinNewest)
                root.selectNewest()
            if (searchField)
                searchField.forceActiveFocus()
        })
    }

    function leave() {
        searchField.text = ""
        filterMenuOpen = false
        markedLines = []
        focusPane = "list"
        previewFullText = ""
        keyboardNav = false
        navPointer = Qt.point(-1, -1)
        pinNewest = false
    }

    function close() {
        if (host && typeof host.close === "function")
            host.close()
    }

    function toggleFilter() {
        if (visible && host && host.open)
            toggleFilterMenu()
    }

    function showFilter() {
        toggleFilter()
    }

    function openFilter() {
        toggleFilter()
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

    function beginKeyboardNav() {
        pinNewest = false
        keyboardNav = true
        navPointer = Qt.point(-1, -1)
    }

    function moveFilterHighlight(delta) {
        const n = filterOptions.length
        if (n <= 0)
            return
        const next = filterHighlight + delta
        if (next < 0 || next >= n)
            return
        beginKeyboardNav()
        filterHighlight = next
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

    function applyFilter(preferId) {
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
        if (pinNewest) {
            selectNewest()
            return
        }
        if (preferId) {
            for (let i = 0; i < listModel.length; i++) {
                const row = listModel[i]
                if (row && row.kind === "item" && row.item && String(row.item.id) === String(preferId)) {
                    selectedIndex = i
                    return
                }
            }
        }
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
            listView.forceLayout()
            listView.positionViewAtBeginning()
            const origin = Number(listView.originY) || 0
            listView.contentY = origin
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
        const step = delta > 0 ? 1 : -1
        const hops = Math.max(1, Math.abs(delta))
        let i = from
        for (let h = 0; h < hops; h++) {
            let found = -1
            for (let n = i + step; n >= 0 && n < listModel.length; n += step) {
                if (listModel[n] && listModel[n].kind === "item") {
                    found = n
                    break
                }
            }
            if (found < 0)
                return i
            i = found
        }
        return i
    }

    function moveSelection(delta) {
        if (!listModel || listModel.length === 0)
            return
        beginKeyboardNav()
        selectedIndex = nextItemIndex(selectedIndex, delta)
        listView.positionViewAtIndex(selectedIndex, ListView.Contain)
        if (focusPane === "preview")
            loadPreviewBody()
    }

    function focusListPane() {
        focusPane = "list"
        searchField.forceActiveFocus()
    }

    function refocusInput() {
        if (filterMenuOpen) {
            searchField.forceActiveFocus()
            return
        }
        if (focusPane === "preview" && previewEdit) {
            previewEdit.forceActiveFocus()
            previewEdit.cursorVisible = true
            return
        }
        searchField.forceActiveFocus()
    }

    function focusPreviewPane() {
        if (!selectedItem || selectedItem.isImage)
            return
        focusPane = "preview"
        loadPreviewBody()
        Qt.callLater(() => root.placePreviewCursorAtStart())
    }

    function placePreviewCursorAtStart() {
        if (!previewEdit)
            return
        previewEdit.forceActiveFocus()
        previewEdit.cursorVisible = true
        previewEdit.deselect()
        previewEdit.cursorPosition = 0
        if (previewFlick)
            previewFlick.contentY = 0
    }

    function ensurePreviewCursorVisible() {
        if (!previewEdit || !previewFlick)
            return
        const r = previewEdit.cursorRectangle
        const pad = 6
        const top = r.y - pad
        const bot = r.y + r.height + pad
        const viewTop = previewFlick.contentY
        const viewBot = viewTop + previewFlick.height
        if (top < viewTop)
            previewFlick.contentY = Math.max(0, top)
        else if (bot > viewBot)
            previewFlick.contentY = Math.max(0, bot - previewFlick.height)
    }

    function previewGo(pos, shift) {
        if (!previewEdit)
            return
        const len = (previewEdit.text || "").length
        pos = Math.max(0, Math.min(len, pos))
        if (shift)
            previewEdit.moveCursorSelection(pos)
        else
            previewEdit.cursorPosition = pos
        previewEdit.cursorVisible = true
        root.ensurePreviewCursorVisible()
    }

    function previewWordPos(pos, dir) {
        const text = previewEdit ? (previewEdit.text || "") : ""
        const len = text.length
        if (dir > 0) {
            while (pos < len && /\s/.test(text.charAt(pos)))
                pos++
            while (pos < len && !/\s/.test(text.charAt(pos)))
                pos++
        } else {
            while (pos > 0 && /\s/.test(text.charAt(pos - 1)))
                pos--
            while (pos > 0 && !/\s/.test(text.charAt(pos - 1)))
                pos--
        }
        return pos
    }

    function previewLinePos(dir) {
        const r = previewEdit.cursorRectangle
        const y = r.y + r.height / 2 + dir * Math.max(r.height, 1)
        return previewEdit.positionAt(r.x, y)
    }

    function handlePreviewNav(event) {
        if (!previewEdit)
            return false
        const ctrl = !!(event.modifiers & Qt.ControlModifier)
        const shift = !!(event.modifiers & Qt.ShiftModifier)
        const pos = previewEdit.cursorPosition
        const text = previewEdit.text || ""

        if (event.key === Qt.Key_Left) {
            root.previewGo(ctrl ? root.previewWordPos(pos, -1) : pos - 1, shift)
            return true
        }
        if (event.key === Qt.Key_Right) {
            root.previewGo(ctrl ? root.previewWordPos(pos, 1) : pos + 1, shift)
            return true
        }
        if (event.key === Qt.Key_Up) {
            root.previewGo(root.previewLinePos(-1), shift)
            return true
        }
        if (event.key === Qt.Key_Down) {
            root.previewGo(root.previewLinePos(1), shift)
            return true
        }
        if (event.key === Qt.Key_Home) {
            if (ctrl) {
                root.previewGo(0, shift)
            } else {
                const nl = text.lastIndexOf("\n", Math.max(0, pos - 1))
                root.previewGo(nl + 1, shift)
            }
            return true
        }
        if (event.key === Qt.Key_End) {
            if (ctrl) {
                root.previewGo(text.length, shift)
            } else {
                const nl = text.indexOf("\n", pos)
                root.previewGo(nl < 0 ? text.length : nl, shift)
            }
            return true
        }
        return false
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
        loadPreviewBody()
        if (focusPane === "preview" && (!selectedItem || selectedItem.isImage))
            focusListPane()
        else if (focusPane === "preview")
            Qt.callLater(() => root.placePreviewCursorAtStart())
    }

    function handleKey(event) {
        if (!root.open)
            return false

        const meta = !!(event.modifiers & Qt.MetaModifier)
        const cmd = VimKeys.resolve(event)

        if (root.isCtrlP(event)) {
            root.toggleFilterMenu()
            return true
        }

        // Super+H / Super+L — physical keys (works on RU layout)
        if (meta && cmd === "l") {
            if (root.filterMenuOpen)
                root.closeFilterMenu()
            root.focusPreviewPane()
            return true
        }
        if (meta && cmd === "h") {
            if (root.filterMenuOpen)
                root.closeFilterMenu()
            root.focusListPane()
            return true
        }

        if (root.filterMenuOpen) {
            if (event.key === Qt.Key_Escape || cmd === "escape") {
                root.closeFilterMenu()
                return true
            }
            if (event.key === Qt.Key_Down || cmd === "down") {
                root.moveFilterHighlight(1)
                return true
            }
            if (event.key === Qt.Key_Up || cmd === "up") {
                root.moveFilterHighlight(-1)
                return true
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || cmd === "enter") {
                root.applyFilterHighlight()
                return true
            }
            return true
        }

        if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Back)
                && searchField.text.length === 0
                && host && typeof host.popView === "function" && host.popView())
            return true

        if (event.key === Qt.Key_Escape || cmd === "escape") {
            if (root.focusPane === "preview") {
                root.focusListPane()
                return true
            }
            if (searchField.text.length > 0) {
                searchField.text = ""
                return true
            }
            if (host && host.canPop === false && typeof host.close === "function") {
                host.close()
                return true
            }
            OverlayHub.pop(host || root)
            return true
        }

        if ((event.modifiers & Qt.ControlModifier) && cmd === "c") {
            root.copyCurrent()
            return true
        }
        if (root.focusPane === "preview" && (event.modifiers & Qt.ControlModifier) && cmd === "a") {
            if (previewEdit)
                previewEdit.selectAll()
            return true
        }

        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ShiftModifier)) {
            root.toggleMarkAt(root.selectedIndex)
            return true
        }

        if (root.focusPane === "preview") {
            if (root.handlePreviewNav(event))
                return true
            return false
        }

        if (event.key === Qt.Key_Down || cmd === "down") {
            root.moveSelection(1)
            return true
        }
        if (event.key === Qt.Key_Up || cmd === "up") {
            root.moveSelection(-1)
            return true
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || cmd === "enter") {
            root.activateSelected()
            return true
        }
        return false
    }

    function isMarked(item) {
        if (!item || !item.line)
            return false
        return markedLines.indexOf(item.line) >= 0
    }

    function isCtrlP(event) {
        const ctrl = !!(event.modifiers & Qt.ControlModifier)
        const meta = !!(event.modifiers & Qt.MetaModifier)
        const alt = !!(event.modifiers & Qt.AltModifier)
        const shift = !!(event.modifiers & Qt.ShiftModifier)
        if (!ctrl || meta || alt || shift)
            return false
        return VimKeys.resolve(event) === "p"
    }

    function toggleMarkAt(index) {
        if (!listModel || index < 0 || index >= listModel.length)
            return
        const row = listModel[index]
        if (!row || row.kind !== "item")
            return
        const item = row.item
        if (!item || !item.line)
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

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\"'\"'") + "'"
    }

    function copyPreviewSelection() {
        if (!previewEdit)
            return false
        const t = previewEdit.selectedText
        if (!t || !String(t).length)
            return false
        const q = shQuote(t)
        Quickshell.execDetached(["bash", "-c", "printf %s " + q + " | wl-copy"])
        return true
    }

    function copyItem(item) {
        if (!item || !item.line)
            return
        Quickshell.execDetached([
            "bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-copy-from-line.sh",
            item.line
        ])
    }

    function copyCurrent() {
        if (root.focusPane === "preview" && root.copyPreviewSelection()) {
            root.close()
            return
        }
        root.copyItem(root.selectedItem)
        root.close()
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

    function itemClock(item) {
        const s = item && item.mtimeLabel ? String(item.mtimeLabel) : ""
        const i = s.lastIndexOf(" ")
        return i >= 0 ? s.slice(i + 1) : s
    }

    function looksLikeCode(item) {
        if (!item || item.isImage)
            return false
        const t = String(item.preview || item.label || "")
        if (t.indexOf("```") >= 0)
            return true
        if (/^(package |import |from |def |class |function |const |let |var |#!\/)/m.test(t))
            return true
        if (/<(html|meta|div|span|script|style|svg|!DOCTYPE)\b/i.test(t))
            return true
        if (/^\s*[{\[]/.test(t) && /[}\]]/.test(t) && /[:,"]/.test(t))
            return true
        const lines = (t.match(/\n/g) || []).length
        if (lines >= 3 && /[{};=]/.test(t))
            return true
        return false
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

    Process {
        id: captureFocus
        command: ["bash", "-c", "hyprctl activewindow -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(\"address\",\"\"))'"]
        stdout: StdioCollector {
            onStreamFinished: root.prevAddr = text.trim()
        }
    }

    Process {
        id: cacheProc
        command: ["bash", root.indexHelper, "--cached"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.liveIndexReady || !text || !text.trim())
                    return
                try {
                    const data = JSON.parse(text)
                    root.items = data.items || []
                    if (root.open)
                        root.applyFilter(root.selectedItem ? root.selectedItem.id : null)
                    else
                        root.applyFilter()
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: indexProc
        command: ["bash", root.indexHelper]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const preferId = (root.open && root.selectedItem) ? root.selectedItem.id : null
                    root.items = data.items || []
                    root.liveIndexReady = true
                    root.applyFilter(preferId)
                } catch (e) {
                    if (!root.items || root.items.length === 0)
                        root.items = []
                }
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
                    root.previewOriginal = body
                    if (previewEdit) {
                        const keepPos = previewEdit.activeFocus ? previewEdit.cursorPosition : 0
                        const keepStart = previewEdit.selectionStart
                        const keepEnd = previewEdit.selectionEnd
                        previewEdit.text = body
                        if (previewEdit.activeFocus) {
                            previewEdit.cursorPosition = Math.min(keepPos, previewEdit.text.length)
                            if (keepStart !== keepEnd)
                                previewEdit.select(Math.min(keepStart, body.length), Math.min(keepEnd, body.length))
                            previewEdit.forceActiveFocus()
                            previewEdit.cursorVisible = true
                        }
                    }
                }
                root.previewLoading = false
                if (root.focusPane === "preview" && previewEdit && previewEdit.cursorPosition === 0
                        && previewEdit.selectionStart === previewEdit.selectionEnd
                        && previewFlick)
                    previewFlick.contentY = 0
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.previewLoading = false
            if (root.focusPane === "preview" && previewEdit) {
                previewEdit.forceActiveFocus()
                previewEdit.cursorVisible = true
            }
        }
    }

    HoverHandler {
        enabled: root.keyboardNav
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        cursorShape: Qt.BlankCursor
        onPointChanged: {
            const p = point.position
            if (root.navPointer.x < 0) {
                root.navPointer = Qt.point(p.x, p.y)
                return
            }
            if (Math.abs(p.x - root.navPointer.x) > 3 || Math.abs(p.y - root.navPointer.y) > 3) {
                root.keyboardNav = false
                root.pinNewest = false
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: DS.Tokens.paddingSurface
        spacing: 8

        Item {
            id: searchRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: DS.Tokens.searchFieldHeight
            Layout.minimumHeight: DS.Tokens.searchFieldHeight
            Layout.maximumHeight: DS.Tokens.searchFieldHeight

            DS.SearchField {
                id: searchFieldBox
                anchors.left: parent.left
                anchors.right: filterChip.left
                anchors.rightMargin: DS.Tokens.gapInline
                height: parent.height
                placeholder: "Search clipboard…"
                hintKeys: ["super", "Q"]
                keyHandler: event => root.handleKey(event)
                pointerHidden: root.keyboardNav
                onTextChanged: root.applyFilter()
            }

            DS.FilterChip {
                id: filterChip
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: root.typeFilterLabel
                menuOpen: root.filterMenuOpen
                onClicked: root.toggleFilterMenu()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 16
            spacing: 0

                    Item {
                        id: listPane
                        Layout.preferredWidth: root.listWidth
                        Layout.minimumWidth: root.listWidth
                        Layout.maximumWidth: root.listWidth
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        implicitWidth: root.listWidth
                        implicitHeight: 100

                        DS.ContentScrim {
                            anchors.fill: parent
                            radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                        }

                        ListView {
                            id: listView
                            anchors.fill: parent
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4
                            anchors.leftMargin: 4
                            anchors.rightMargin: 8
                            clip: true
                            spacing: 2
                            model: root.listModel
                            currentIndex: root.selectedIndex
                            highlightFollowsCurrentItem: false
                            keyNavigationWraps: false
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                required property var modelData
                                required property int index
                                width: ListView.view ? ListView.view.width : listPane.width
                                height: modelData.kind === "header" ? DS.Tokens.sectionHeight : DS.Tokens.rowHeight

                                readonly property bool rowImage: !!(modelData.item && modelData.item.isImage)
                                readonly property bool rowCode: !rowImage && root.looksLikeCode(modelData.item)
                                readonly property bool marked: !!(modelData.item && root.isMarked(modelData.item))

                                DS.SectionLabel {
                                    visible: modelData.kind === "header"
                                    anchors.left: parent.left
                                    anchors.leftMargin: DS.Tokens.rowPaddingX
                                    anchors.right: parent.right
                                    anchors.rightMargin: DS.Tokens.rowPaddingX
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    label: modelData.title || ""
                                }

                                Item {
                                    visible: modelData.kind === "item"
                                    anchors.fill: parent
                                    opacity: root.focusPane === "preview" ? 0.72 : 1

                                    DS.SelectionPill {
                                        anchors.fill: parent
                                        hovered: rowMouse.containsMouse && !root.keyboardNav
                                        selected: index === root.selectedIndex
                                        muted: marked
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: DS.Tokens.rowPaddingX
                                        anchors.rightMargin: DS.Tokens.rowPaddingX
                                        spacing: DS.Tokens.gapInline

                                        Item {
                                            Layout.preferredWidth: rowImage ? 40 : DS.Tokens.leadingSize
                                            Layout.preferredHeight: DS.Tokens.leadingSize

                                            Image {
                                                anchors.fill: parent
                                                visible: rowImage
                                                source: modelData.item ? root.thumbUrl(modelData.item) : ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: true
                                            }

                                            DS.QuietText {
                                                anchors.centerIn: parent
                                                visible: !rowImage
                                                text: rowCode ? "{ }" : "Aa"
                                                color: DS.Tokens.textTertiary
                                                font.family: DS.Tokens.fontUi
                                                font.pixelSize: DS.Tokens.fontSizeSm
                                                fontWeight: Font.Medium
                                            }
                                        }

                                        DS.QuietText {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            text: modelData.item ? (modelData.item.label || "") : ""
                                            color: DS.Tokens.textPrimary
                                            font.family: DS.Tokens.fontUi
                                            font.pixelSize: DS.Tokens.fontSize
                                            fontWeight: Font.Medium
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        DS.QuietText {
                                            visible: !!(modelData.item && root.itemClock(modelData.item))
                                            Layout.fillHeight: true
                                            text: modelData.item ? root.itemClock(modelData.item) : ""
                                            color: DS.Tokens.textTertiary
                                            font.family: DS.Tokens.fontUi
                                            font.pixelSize: DS.Tokens.fontSizeSm
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: !root.keyboardNav
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: root.keyboardNav ? Qt.BlankCursor : Qt.ArrowCursor
                                        onEntered: {
                                            if (root.keyboardNav)
                                                return
                                            root.pinNewest = false
                                            root.selectedIndex = index
                                        }
                                        onClicked: mouse => {
                                            root.pinNewest = false
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

                            DS.QuietText {
                                anchors.centerIn: parent
                                visible: !root.filtered || root.filtered.length === 0
                                text: (indexProc.running || cacheProc.running) && (!root.items || root.items.length === 0)
                                      ? "Loading…"
                                      : "Nothing found"
                                color: DS.Tokens.textTertiary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSize
                            }
                        }

                        DS.ScrollIndicator {
                            view: listView
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 4
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                        color: DS.Tokens.hairline
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 280

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: 20
                            anchors.bottomMargin: root.previewMeta.length ? 48 : 20
                            visible: root.selectedItem && root.selectedItem.isImage
                            source: root.selectedItem ? root.previewUrl(root.selectedItem) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                        }

                        Item {
                            anchors.fill: parent
                            visible: root.selectedItem && !root.selectedItem.isImage

                                Flickable {
                                    id: previewFlick
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: root.previewMeta.length ? 40 : 8
                                    contentWidth: width
                                    contentHeight: previewEdit.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    interactive: true
                                    flickableDirection: Flickable.VerticalFlick
                                    Keys.enabled: false

                                    TextEdit {
                                        id: previewEdit
                                        width: previewFlick.width
                                        color: DS.Tokens.textPrimary
                                        font.family: root.selectedIsCode ? Colors.font_mono : DS.Tokens.fontUi
                                        font.pixelSize: DS.Tokens.fontSize
                                        font.weight: Font.Medium
                                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                                        readOnly: true
                                        selectByMouse: true
                                        selectByKeyboard: true
                                        persistentSelection: true
                                        activeFocusOnPress: true
                                        cursorVisible: activeFocus
                                        selectionColor: DS.Tokens.raisedStrong
                                        selectedTextColor: DS.Tokens.textPrimary

                                        cursorDelegate: Rectangle {
                                            width: 2
                                            color: DS.Tokens.textPrimary
                                            visible: previewEdit.activeFocus
                                            SequentialAnimation on opacity {
                                                running: previewEdit.activeFocus
                                                loops: Animation.Infinite
                                                NumberAnimation { from: 1; to: 0; duration: 530 }
                                                NumberAnimation { from: 0; to: 1; duration: 530 }
                                            }
                                        }

                                        onActiveFocusChanged: {
                                            if (activeFocus) {
                                                root.focusPane = "preview"
                                                cursorVisible = true
                                            }
                                        }

                                        onCursorRectangleChanged: root.ensurePreviewCursorVisible()

                                        Keys.onPressed: event => {
                                            if (root.handleKey(event))
                                                event.accepted = true
                                        }
                                    }
                                }

                                DS.ScrollIndicator {
                                    view: previewFlick
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.topMargin: 16
                                    anchors.bottomMargin: 16
                                }

                                DS.QuietText {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 16
                                    visible: root.previewLoading
                                    text: "loading…"
                                    color: DS.Tokens.textTertiary
                                    font.family: DS.Tokens.fontUi
                                    font.pixelSize: DS.Tokens.fontSizeSm
                                }
                            }

                            DS.QuietText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20
                                anchors.bottomMargin: 12
                                visible: !!root.selectedItem && !root.previewLoading && root.previewMeta.length > 0
                                text: root.previewMeta
                                color: DS.Tokens.textTertiary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSizeSm
                                elide: Text.ElideRight
                            }

                            DS.QuietText {
                                anchors.centerIn: parent
                                visible: !root.selectedItem
                                text: "Select an entry"
                                color: DS.Tokens.textTertiary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSize
                            }
                    }
                }

                DS.FooterHints {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: DS.Tokens.footerHeight
                    Layout.maximumHeight: DS.Tokens.footerHeight
                    closeHint: (host && host.canPop)
                        ? ({ keys: ["esc"], label: "Back" })
                        : ({ keys: ["esc"], label: "Close" })
                    hints: {
                        if (root.filterMenuOpen)
                            return [
                                { keys: ["↑", "↓"], label: "Filter" },
                                { keys: ["⏎"], label: "Choose" }
                            ]
                        if (root.focusPane === "preview")
                            return [
                                { keys: ["⇧", "←", "→"], label: "Select" },
                                { keys: ["ctrl", "C"], label: "Copy" },
                                { keys: ["super", "H"], label: "List" }
                            ]
                        return [
                            { keys: ["↑", "↓"], label: "Navigate" },
                            { keys: ["super", "L"], label: "Preview" },
                            { keys: ["⇧", "⏎"], label: "Mark" },
                            { keys: ["ctrl", "C"], label: "Copy" },
                            { keys: ["⏎"], label: root.pasteHintLabel }
                        ]
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.filterMenuOpen
                z: 20
                onClicked: root.closeFilterMenu()
            }

            DS.FilterDropdown {
                visible: root.filterMenuOpen
                options: root.filterOptions
                highlight: root.filterHighlight
                currentValue: root.typeFilter
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: DS.Tokens.paddingSurface + DS.Tokens.searchFieldHeight + 4
                anchors.rightMargin: DS.Tokens.paddingSurface
                z: 30
                onPicked: index => {
                    root.filterHighlight = index
                    root.applyFilterHighlight()
                }
            }
}
