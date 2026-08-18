import QtQuick

// Popup Surface composition v2 (ADR-0005): Search field (anchor) / sectioned List /
// Footer hints — zones separated by air and material levels, never by lines.
// Model items may include non-selectable entries (e.g. { kind: "header" });
// keyboard navigation skips them via `selectable`.
PopupSurface {
    id: root

    property string placeholder: "Search…"
    property var hintKeys: []
    property var model: []
    property int selectedIndex: 0
    property int maxRows: 8
    property var footerHints: [
        { keys: ["↑", "↓"], label: "Navigate" },
        { keys: ["⏎"], label: "Open" }
    ]
    property Component rowDelegate: null
    // function(item) -> bool
    property var selectable: function (item) {
        return !(item && item.kind === "header")
    }

    property alias searchText: search.text
    readonly property alias listView: list
    // Keyboard ↑/↓ hides the pointer and ignores hover until the mouse moves.
    property bool keyboardNav: false
    property point navPointer: Qt.point(-1, -1)

    signal activated(var item, int index)

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
            const step = Tokens.rowHeight + list.spacing
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

    onPopupOpened: {
        search.text = ""
        selectFirst()
        keyboardNav = false
        navPointer = Qt.point(-1, -1)
        Qt.callLater(() => search.input.forceActiveFocus())
    }

    // Esc clears a non-empty query first, then falls through to close.
    keyHandler: function (event) {
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
        if (event.key === Qt.Key_Escape && search.text.length > 0) {
            search.text = ""
            return true
        }
        return false
    }

    Column {
        width: parent.width
        topPadding: Tokens.paddingSurface
        bottomPadding: Tokens.paddingSurface
        leftPadding: Tokens.paddingSurface
        rightPadding: Tokens.paddingSurface
        spacing: 8

        SearchField {
            id: search
            width: parent.width - 2 * Tokens.paddingSurface
            placeholder: root.placeholder
            hintKeys: root.hintKeys
            keyHandler: root.handleKey
            pointerHidden: root.keyboardNav
        }

        Item {
            width: parent.width - 2 * Tokens.paddingSurface
            implicitHeight: {
                const max = root.maxRows * Tokens.rowHeight
                const content = list.contentHeight + 8
                return Math.max(72, Math.min(content, max))
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

                    Text {
                        anchors.centerIn: parent
                        visible: root.firstSelectable() < 0
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
            hints: root.footerHints
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
