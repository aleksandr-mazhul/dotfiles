import QtQuick
import ".."
import "../vim"

// Inner chrome of SearchListPopup, also used as a launcher page (wallpaper, VPN).
// Not a window: host is the PopupSurface. Esc empty-search falls through to host.
Item {
    id: root

    property var host: null
    property string pageId: ""
    readonly property bool open: !!(host && host.open)

    implicitHeight: col.implicitHeight
    implicitWidth: width
    // Same plate as launcher home: well is always maxRows tall, not content-sized.
    readonly property int wellHeight: maxRows * rowSize

    property string placeholder: "Search…"
    property var hintKeys: []
    property var model: []
    property int selectedIndex: 0
    property int maxRows: 8
    property int rowSize: Tokens.rowHeight
    // Return true to consume the key before the default list handler.
    property var customKeyHandler: null
    property var footerHints: [
        { keys: ["↑", "↓"], label: "Navigate" },
        { keys: ["⏎"], label: "Open" }
    ]
    property var closeHint: ({ keys: ["esc"], label: "Close" })
    property Component rowDelegate: null
    // function(item) -> bool
    property var selectable: function (item) {
        return !(item && item.kind === "header")
    }

    // Optional category / type filter: pill top-right + dropdown (RicePanel Ctrl+P).
    property var filterOptions: [] // [{ value, label }, ...]
    property string filterValue: ""
    property string filterPlaceholder: "Filter"
    property bool filterMenuOpen: false
    property int filterHighlight: 0
    property bool pendingOpenFilter: false
    readonly property bool hasFilter: filterOptions && filterOptions.length > 0
    readonly property string filterLabelText: {
        if (!hasFilter)
            return filterPlaceholder
        const opts = filterOptions
        const val = filterValue
        for (let i = 0; i < opts.length; i++) {
            if (opts[i].value === val)
                return opts[i].label
        }
        return filterPlaceholder
    }
    signal filterChanged(string value)

    property alias searchText: search.text
    readonly property alias listView: list
    // Keyboard ↑/↓ hides the pointer and ignores hover until the mouse moves.
    property bool keyboardNav: false
    property point navPointer: Qt.point(-1, -1)

    signal activated(var item, int index)
    signal pageEntered()
    signal pageLeft()

    function canSelect(i) {
        if (!model || i < 0 || i >= model.length)
            return false
        return selectable(model[i])
    }

    function firstSelectable() {
        for (let i = 0; i < (model ? model.length : 0); i++) {
            if (canSelect(i))
                return i
        }
        return -1
    }

    function scrollToStart() {
        const pin = () => {
            if (!list)
                return
            list.contentY = Number(list.originY) || 0
        }
        // Do not forceLayout() here: during ListView incubation Qt 6.11 SIGSEGVs
        // in QQmlIncubator / QMetaObject::propertyCount.
        if (list.count > 0)
            list.positionViewAtBeginning()
        pin()
        Qt.callLater(() => {
            if (root.selectedIndex === firstSelectable()) {
                pin()
                return
            }
            const item = list.itemAtIndex(root.selectedIndex)
            if (!item || !list.contentItem)
                return
            const origin = Number(list.originY) || 0
            const y = item.mapToItem(list.contentItem, 0, 0).y
            if (y + item.height <= origin + list.height + 1)
                pin()
        })
    }

    function revealIndex(i, delta) {
        if (i === firstSelectable()) {
            scrollToStart()
            return
        }

        const origin = Number(list.originY) || 0
        const maxY = origin + Math.max(0, list.contentHeight - list.height)
        const item = list.itemAtIndex(i)

        // Anything that already fits on the first screen stays pinned to the
        // top — otherwise the first app lands flush with the clip edge.
        if (item && list.contentItem) {
            const y = item.mapToItem(list.contentItem, 0, 0).y
            if (y + item.height <= origin + list.height + 1) {
                scrollToStart()
                return
            }
        }

        if (!item) {
            const step = root.rowSize + list.spacing
            list.contentY = Math.max(origin, Math.min(maxY, list.contentY + (delta > 0 ? step : -step)))
            return
        }

        let cy = list.contentY
        const topInView = item.mapToItem(list, 0, 0).y
        const botInView = topInView + item.height
        if (botInView > list.height)
            cy += botInView - list.height
        if (topInView < 0)
            cy += topInView

        if (delta < 0 && i > 0 && model[i - 1] && model[i - 1].kind === "header") {
            const header = list.itemAtIndex(i - 1)
            if (header) {
                const ht = header.mapToItem(list, 0, 0).y
                if (ht < 0)
                    cy += ht
            } else {
                cy -= Tokens.sectionHeight + list.spacing
            }
        }

        list.contentY = Math.max(origin, Math.min(maxY, cy))
    }

    function moveSelection(delta) {
        const n = model ? model.length : 0
        if (n === 0)
            return
        let i = selectedIndex
        for (let step = 0; step < n; step++) {
            i += delta
            if (i < 0 || i >= n)
                return
            if (canSelect(i)) {
                keyboardNav = true
                navPointer = Qt.point(-1, -1)
                selectedIndex = i
                revealIndex(i, delta)
                return
            }
        }
    }

    function activateSelected() {
        if (!canSelect(selectedIndex))
            return
        activated(model[selectedIndex], selectedIndex)
    }

    function selectFirst() {
        selectedIndex = firstSelectable()
        if (selectedIndex >= 0)
            scrollToStart()
    }

    function clampSelection() {
        if (canSelect(selectedIndex))
            return
        selectFirst()
    }

    // Typing is keyboard input: ignore hover until the pointer actually moves,
    // otherwise a rebuilt row under the cursor steals the first (best) match.
    onSearchTextChanged: {
        if (String(searchText).trim()) {
            keyboardNav = true
            navPointer = Qt.point(-1, -1)
        }
    }

    onModelChanged: {
        // Defer until after QQmlIncubator finishes creating delegates.
        Qt.callLater(() => {
            if (String(searchText).trim())
                selectFirst()
            else
                clampSelection()
        })
    }
    onSelectedIndexChanged: {
        if (selectedIndex === firstSelectable())
            scrollToStart()
    }

    function focusSearch() {
        Qt.callLater(() => {
            if (search && search.input)
                search.input.forceActiveFocus()
        })
    }

    function enter() {
        search.text = ""
        selectFirst()
        keyboardNav = false
        navPointer = Qt.point(-1, -1)
        filterMenuOpen = false
        pageEntered()
        Qt.callLater(() => {
            if (root.pendingOpenFilter && root.hasFilter) {
                root.pendingOpenFilter = false
                root.openFilterMenu()
            } else {
                root.pendingOpenFilter = false
                search.input.forceActiveFocus()
            }
        })
    }

    function leave() {
        filterMenuOpen = false
        pendingOpenFilter = false
        pageLeft()
    }

    function onHostResumed() {
        filterMenuOpen = false
        Qt.callLater(() => search.input.forceActiveFocus())
    }

    function close() {
        if (host && typeof host.close === "function")
            host.close()
    }

    function show() {
        if (host && typeof host.show === "function")
            host.show()
    }

    function hide() {
        if (host && typeof host.hide === "function")
            host.hide()
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

    function toggleFilter() {
        if (!hasFilter)
            return
        if (open) {
            toggleFilterMenu()
            return
        }
        pendingOpenFilter = true
        if (host && pageId && typeof host.openPage === "function")
            host.openPage(pageId)
        else
            show()
    }

    function showFilter() {
        toggleFilter()
    }

    function syncFilterHighlight() {
        if (!hasFilter) {
            filterHighlight = 0
            return
        }
        let idx = 0
        for (let i = 0; i < filterOptions.length; i++) {
            if (filterOptions[i].value === filterValue) {
                idx = i
                break
            }
        }
        filterHighlight = idx
    }

    function openFilterMenu() {
        if (!hasFilter)
            return
        syncFilterHighlight()
        filterMenuOpen = true
        search.input.forceActiveFocus()
    }

    function closeFilterMenu() {
        filterMenuOpen = false
        search.input.forceActiveFocus()
    }

    function toggleFilterMenu() {
        if (filterMenuOpen)
            closeFilterMenu()
        else
            openFilterMenu()
    }

    function moveFilterHighlight(delta) {
        if (!hasFilter)
            return
        const n = filterOptions.length
        if (n <= 0)
            return
        const next = filterHighlight + delta
        if (next < 0 || next >= n)
            return
        keyboardNav = true
        navPointer = Qt.point(-1, -1)
        filterHighlight = next
    }

    function applyFilterHighlight() {
        if (!hasFilter || filterHighlight < 0 || filterHighlight >= filterOptions.length)
            return
        const opt = filterOptions[filterHighlight]
        filterValue = opt.value
        filterMenuOpen = false
        filterChanged(opt.value)
        search.input.forceActiveFocus()
    }

    function handleKey(event) {
        if (root.hasFilter && root.isCtrlP(event)) {
            root.toggleFilterMenu()
            return true
        }
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
        if (typeof customKeyHandler === "function" && customKeyHandler(event))
            return true
        if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Back)
                && String(search.text).length === 0
                && host && typeof host.popView === "function" && host.popView())
            return true
        if (event.key === Qt.Key_Down) {
            moveSelection(1)
            return true
        }
        if (event.key === Qt.Key_Up) {
            moveSelection(-1)
            return true
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateSelected()
            return true
        }
        if (event.key === Qt.Key_Escape) {
            if (search.text.length > 0) {
                search.text = ""
                return true
            }
            if (host && host.canPop === false && typeof host.close === "function") {
                host.close()
                return true
            }
            if (host && typeof host.handleKey === "function")
                return host.handleKey(event)
            return false
        }
        if (host && typeof host.handleKey === "function")
            return host.handleKey(event)
        return false
    }

    Keys.onPressed: event => {
        if (search.input && search.input.activeFocus)
            return
        if (root.handleKey(event))
            event.accepted = true
    }

    Column {
        id: col
        width: parent.width
        topPadding: Tokens.paddingSurface
        bottomPadding: Tokens.paddingSurface
        leftPadding: Tokens.paddingSurface
        rightPadding: Tokens.paddingSurface
        spacing: 8

        Item {
            id: searchRow
            width: parent.width - 2 * Tokens.paddingSurface
            height: Tokens.searchFieldHeight

            SearchField {
                id: search
                anchors.left: parent.left
                anchors.right: filterChip.visible ? filterChip.left : parent.right
                anchors.rightMargin: filterChip.visible ? 8 : 0
                height: parent.height
                placeholder: root.placeholder
                hintKeys: root.hintKeys
                keyHandler: root.handleKey
                pointerHidden: root.keyboardNav
            }

            Item {
                id: filterChip
                visible: root.hasFilter
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: visible ? Math.max(118, chipRow.implicitWidth + 20) : 0

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radiusField
                    color: Tokens.fieldFill
                    border.width: 1
                    border.color: root.filterMenuOpen ? Tokens.focusRim : Tokens.fieldRim
                }

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6

                    QuietText {
                        text: root.filterLabelText
                        color: Tokens.textPrimary
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.fontSizeSm
                        width: implicitWidth
                        height: implicitHeight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    KbdBadge {
                        key: "ctrl"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    KbdBadge {
                        key: "P"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    QuietText {
                        text: "☰"
                        color: Tokens.textTertiary
                        font.pixelSize: Tokens.fontSizeSm
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleFilterMenu()
                }
            }
        }

        Item {
            width: parent.width - 2 * Tokens.paddingSurface
            implicitHeight: root.wellHeight
            height: root.wellHeight

            ContentScrim {
                anchors.fill: parent
                radius: Tokens.innerRadius(Tokens.radiusSurface, Tokens.paddingSurface)
            }

            Item {
                anchors.fill: parent
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    clip: false
                    spacing: 2
                    model: root.model
                    currentIndex: root.selectedIndex
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: false
                    highlightMoveDuration: 0
                    highlightResizeDuration: 0
                    keyNavigationWraps: false
                    delegate: root.rowDelegate

                    QuietText {
                        anchors.centerIn: parent
                        visible: !root.model || root.model.length === 0
                        text: "Nothing found"
                        color: Tokens.textTertiary
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.fontSize
                    }
                }
            }

            ScrollIndicator {
                view: list
                anchors.right: parent.right
                anchors.rightMargin: -6
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 4
            }
        }

        FooterHints {
            width: parent.width - 2 * Tokens.paddingSurface
            hints: root.filterMenuOpen
                ? [
                    { keys: ["↑", "↓"], label: "Filter" },
                    { keys: ["⏎"], label: "Choose" }
                ]
                : root.footerHints
            closeHint: root.filterMenuOpen
                ? ({ keys: ["esc"], label: "Close menu" })
                : root.closeHint
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.filterMenuOpen
        z: 20
        onClicked: root.closeFilterMenu()
    }

    FilterDropdown {
        visible: root.filterMenuOpen && root.hasFilter
        options: root.filterOptions
        highlight: root.filterHighlight
        currentValue: root.filterValue
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Tokens.paddingSurface + Tokens.searchFieldHeight + 4
        anchors.rightMargin: Tokens.paddingSurface
        z: 30
        onPicked: index => {
            root.filterHighlight = index
            root.applyFilterHighlight()
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
            if (Math.abs(p.x - root.navPointer.x) > 3 || Math.abs(p.y - root.navPointer.y) > 3)
                root.keyboardNav = false
        }
    }
}
