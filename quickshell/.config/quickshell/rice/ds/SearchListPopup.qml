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

    function moveSelection(delta) {
        const n = model ? model.length : 0
        if (n === 0)
            return
        let i = selectedIndex
        for (let step = 0; step < n; step++) {
            i = (i + delta + n) % n
            if (canSelect(i)) {
                selectedIndex = i
                list.positionViewAtIndex(i, ListView.Contain)
                return
            }
        }
    }

    function activateSelected() {
        if (!canSelect(selectedIndex))
            return
        activated(model[selectedIndex], selectedIndex)
    }

    function clampSelection() {
        if (canSelect(selectedIndex))
            return
        selectedIndex = firstSelectable()
    }

    onModelChanged: clampSelection()

    onPopupOpened: {
        search.text = ""
        selectedIndex = firstSelectable()
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
        width: root.surfaceWidth
        topPadding: Tokens.paddingSurface
        bottomPadding: Tokens.paddingSurface
        leftPadding: Tokens.paddingSurface
        rightPadding: Tokens.paddingSurface
        spacing: 6

        SearchField {
            id: search
            width: parent.width - 2 * Tokens.paddingSurface
            placeholder: root.placeholder
            hintKeys: root.hintKeys
            keyHandler: root.handleKey
        }

        Item {
            width: parent.width - 2 * Tokens.paddingSurface
            implicitHeight: {
                const max = root.maxRows * Tokens.rowHeight
                const content = list.contentHeight + 8
                return Math.max(72, Math.min(content, max))
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.topMargin: 4
                clip: true
                spacing: 2
                model: root.model
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                delegate: root.rowDelegate

                // no-results: one quiet hint line, nothing else
                Text {
                    anchors.centerIn: parent
                    visible: root.firstSelectable() < 0
                    text: "Nothing found"
                    color: Tokens.textTertiary
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.fontSize
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
}
