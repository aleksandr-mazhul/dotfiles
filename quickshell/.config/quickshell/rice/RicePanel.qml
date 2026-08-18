import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "vim"

PanelWindow {
    id: root

    property bool open: false
    property string title: ""
    property string countText: ""
    property string searchPlaceholder: "Search…"
    property alias searchText: searchField.text
    property bool showSearch: true
    property var model: []
    property int selectedIndex: 0
    // Keyboard ↑/↓ hides the pointer and ignores hover until the mouse moves.
    property bool keyboardNav: false
    property point navPointer: Qt.point(-1, -1)
    property int itemHeight: Theme.rowHeight
    property int maxVisible: 8
    property int panelWidth: Theme.panelWidth
    property int panelHeight: Theme.panelHeight
    property int panelMaxHeight: Theme.panelHeight
    property string footerText: "↑↓ move  ·  ↵ select  ·  esc close"
    property Component rowDelegate
    property bool registerWithHub: true

    // Optional filter burger (category / type dropdown)
    property var filterOptions: [] // [{ value, label }, ...]
    property string filterValue: ""
    property bool filterMenuOpen: false
    property int filterHighlight: 0
    property string filterPlaceholder: "Filter"
    property bool pendingOpenFilter: false

    // Return true from customKeyHandler(event) to consume the key.
    property var customKeyHandler: null

    readonly property alias listView: listView
    readonly property alias searchField: searchField
    readonly property bool hasFilter: filterOptions && filterOptions.length > 0

    signal activated(var item, int index)
    signal panelOpened()
    signal panelClosed()
    signal queryChanged(string text)
    signal filterChanged(string value)

    // Stay visible only while open — match Clipboard (no linger mid-close).
    visible: open
    // True while the overlay is on-screen — bar/layer logic uses this.
    readonly property bool surfaceActive: open
    color: "transparent"
    // -1 = own the whole output; Ignore alone still got cropped by the bar's zone (y+52).
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-panel"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    Component.onCompleted: {
        if (registerWithHub)
            OverlayHub.register(root)
    }

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
        keyboardNav = false
        navPointer = Qt.point(-1, -1)
        searchField.text = ""
        filterMenuOpen = false
        panelOpened()
        Qt.callLater(() => root.scrollToStart())
        openAnim.play()
        Qt.callLater(() => {
            if (pendingOpenFilter && hasFilter) {
                pendingOpenFilter = false
                openFilterMenu()
            } else {
                pendingOpenFilter = false
                if (showSearch)
                    searchField.forceActiveFocus()
                else
                    focusCatcher.forceActiveFocus()
            }
        })
    }

    function close() {
        if (!open)
            return
        openAnim.stop()
        open = false
        searchField.text = ""
        filterMenuOpen = false
        pendingOpenFilter = false
        dim.opacity = 0
        panel.opacity = 1
        panel.scale = 1
        panelClosed()
    }

    // Shared filter entry (Ctrl+P): toggle filter if open; otherwise open with filter menu.
    function toggleFilter() {
        if (!hasFilter)
            return
        if (open) {
            toggleFilterMenu()
            return
        }
        pendingOpenFilter = true
        show()
    }

    function openFilter() {
        toggleFilter()
    }

    function showFilter() {
        toggleFilter()
    }

    function scrollToStart() {
        const pin = () => {
            listView.contentY = Number(listView.originY) || 0
        }
        listView.forceLayout()
        pin()
        Qt.callLater(() => {
            if (root.selectedIndex === 0) {
                pin()
                return
            }
            const item = listView.itemAtIndex(root.selectedIndex)
            if (!item || !listView.contentItem)
                return
            const origin = Number(listView.originY) || 0
            const y = item.mapToItem(listView.contentItem, 0, 0).y
            if (y + item.height <= origin + listView.height + 1)
                pin()
        })
    }

    function revealIndex(i, delta) {
        if (i <= 0) {
            scrollToStart()
            return
        }

        listView.forceLayout()
        const origin = Number(listView.originY) || 0
        const maxY = origin + Math.max(0, listView.contentHeight - listView.height)
        const item = listView.itemAtIndex(i)

        // Rows that still fit on the first screen stay pinned to the top.
        if (item && listView.contentItem) {
            const y = item.mapToItem(listView.contentItem, 0, 0).y
            if (y + item.height <= origin + listView.height + 1) {
                scrollToStart()
                return
            }
        }

        if (!item) {
            const step = root.itemHeight + listView.spacing
            listView.contentY = Math.max(origin, Math.min(maxY, listView.contentY + (delta > 0 ? step : -step)))
            return
        }

        let cy = listView.contentY
        const topInView = item.mapToItem(listView, 0, 0).y
        const botInView = topInView + item.height
        if (botInView > listView.height)
            cy += botInView - listView.height
        if (topInView < 0)
            cy += topInView
        listView.contentY = Math.max(origin, Math.min(maxY, cy))
    }

    function moveSelection(delta) {
        if (!model || model.length === 0)
            return
        const next = selectedIndex + delta
        if (next < 0 || next >= model.length)
            return
        keyboardNav = true
        navPointer = Qt.point(-1, -1)
        selectedIndex = next
        revealIndex(next, delta)
    }

    function activateSelected() {
        if (!model || model.length === 0 || selectedIndex < 0 || selectedIndex >= model.length)
            return
        activated(model[selectedIndex], selectedIndex)
    }

    function clampSelection() {
        if (!model || model.length === 0) {
            selectedIndex = 0
            return
        }
        if (selectedIndex >= model.length)
            selectedIndex = model.length - 1
        if (selectedIndex < 0)
            selectedIndex = 0
    }

    function filterLabel() {
        if (!hasFilter)
            return filterPlaceholder
        for (let i = 0; i < filterOptions.length; i++) {
            if (filterOptions[i].value === filterValue)
                return filterOptions[i].label
        }
        return filterPlaceholder
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
        focusCatcher.forceActiveFocus()
    }

    function closeFilterMenu() {
        filterMenuOpen = false
        if (showSearch)
            searchField.forceActiveFocus()
        else
            focusCatcher.forceActiveFocus()
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
        filterHighlight = next
    }

    function applyFilterHighlight() {
        if (!hasFilter || filterHighlight < 0 || filterHighlight >= filterOptions.length)
            return
        const opt = filterOptions[filterHighlight]
        filterValue = opt.value
        filterMenuOpen = false
        filterChanged(opt.value)
        if (showSearch)
            searchField.forceActiveFocus()
        else
            focusCatcher.forceActiveFocus()
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

    function handleKey(event) {
        if (!root.open)
            return false

        // Ctrl+P — in-panel filter (Hyprland also binds this; compositor usually consumes it).
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
            return true // swallow other keys while burger is open
        }

        if (typeof root.customKeyHandler === "function") {
            if (root.customKeyHandler(event))
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
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateSelected()
            return true
        }
        return false
    }

    onModelChanged: {
        clampSelection()
        if (selectedIndex === 0)
            Qt.callLater(() => root.scrollToStart())
    }
    onSelectedIndexChanged: {
        if (selectedIndex === 0)
            scrollToStart()
    }
    onFilterOptionsChanged: syncFilterHighlight()
    onFilterValueChanged: syncFilterHighlight()

    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: root.open && (!root.showSearch || root.filterMenuOpen)

        Keys.onPressed: event => {
            if (root.handleKey(event))
                event.accepted = true
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
        width: root.panelWidth
        height: root.panelHeight
        anchors.centerIn: parent
        radius: Theme.radiusLg
        // Match Clipboard: opaque surface (not translucent glass — that looked like gray fog).
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        clip: true
        transformOrigin: Item.Center
        opacity: 1
        scale: 1

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

        RiceOpenAnim {
            id: openAnim
            target: panel
            dimTarget: dim
            fromScale: 0.98
        }

        // Soft inner highlight — Apple-like glass edge without heavy chrome
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radiusLg - 1
            color: "transparent"
            border.width: 1
            border.color: Theme.outlineSubtle
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.filterMenuOpen)
                    root.closeFilterMenu()
                else if (root.showSearch)
                    searchField.forceActiveFocus()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.countText.length > 0
                    text: root.countText
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
            }

            RowLayout {
                visible: root.showSearch || root.hasFilter
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                spacing: 10

                Rectangle {
                    visible: root.showSearch
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: Theme.radiusMd
                    color: Theme.glassSurface
                    border.color: searchField.activeFocus && !root.filterMenuOpen ? Theme.primary : Theme.glassBorderSubtle
                    border.width: 1
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }

                    RiceIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        customSource: Qt.resolvedUrl("assets/search.svg")
                        tint: Theme.textMuted
                        implicitSize: 15
                    }

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.leftMargin: 38
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
                            text: root.searchPlaceholder
                            color: Theme.textMuted
                            font: searchField.font
                            visible: searchField.text.length === 0
                        }

                        onTextChanged: root.queryChanged(text)

                        Keys.onPressed: event => {
                            if (root.handleKey(event))
                                event.accepted = true
                        }
                    }
                }

                Rectangle {
                    id: filterPill
                    visible: root.hasFilter
                    Layout.preferredWidth: Math.max(110, filterPillLabel.implicitWidth + filterPillHint.implicitWidth + 44)
                    Layout.preferredHeight: 42
                    radius: height / 2
                    color: filterPillHover.containsMouse ? Theme.glassSurfaceHover : Theme.glassSurface
                    border.color: root.filterMenuOpen ? Theme.primary : Theme.glassBorderSubtle
                    border.width: 1
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            id: filterPillLabel
                            text: root.filterLabel()
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }
                        Text {
                            id: filterPillHint
                            text: "⌃P"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            opacity: 0.85
                        }
                        Text {
                            text: "☰"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSizeSm
                        }
                    }

                    MouseArea {
                        id: filterPillHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleFilterMenu()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.rightMargin: scrollBar.visible ? 10 : 0
                    clip: true
                    spacing: 4
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
                        visible: !root.model || root.model.length === 0
                        text: "Nothing found"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }

                // Minimal scroll position indicator (track + thumb).
                Item {
                    id: scrollBar
                    readonly property bool needed: listView.contentHeight > listView.height + 2
                    readonly property real origin: Number(listView.originY) || 0
                    readonly property real ratio: listView.height / Math.max(1, listView.contentHeight)
                    readonly property real thumbH: Math.max(28, height * ratio)
                    readonly property real maxThumbY: Math.max(0, height - thumbH)
                    readonly property real maxContentY: Math.max(1, listView.contentHeight - listView.height)
                    readonly property real thumbY: {
                        if (listView.atYBeginning)
                            return 0
                        const cy = listView.contentY
                        if (!(cy === cy) || cy <= origin + 1)
                            return 0
                        return maxThumbY * Math.max(0, Math.min(1, (cy - origin) / maxContentY))
                    }

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
                        id: scrollThumb
                        x: 0
                        width: parent.width
                        height: scrollBar.thumbH
                        y: scrollBar.thumbY
                        radius: 3
                        color: Theme.primary
                        opacity: scrollDrag.active ? 0.95 : 0.65

                        MouseArea {
                            id: scrollDrag
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            property real grabOffset: 0

                            onPressed: mouse => {
                                grabOffset = mouse.y
                            }
                            onPositionChanged: mouse => {
                                if (!pressed)
                                    return
                                const localY = scrollThumb.y + mouse.y - grabOffset
                                const clamped = Math.max(0, Math.min(scrollBar.maxThumbY, localY))
                                listView.contentY = scrollBar.origin + (clamped / Math.max(1, scrollBar.maxThumbY)) * scrollBar.maxContentY
                            }
                        }
                    }

                    // Click track to jump
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            const target = mouse.y - scrollBar.thumbH / 2
                            const clamped = Math.max(0, Math.min(scrollBar.maxThumbY, target))
                            listView.contentY = scrollBar.origin + (clamped / Math.max(1, scrollBar.maxThumbY)) * scrollBar.maxContentY
                        }
                    }
                }
            }

            Text {
                text: root.filterMenuOpen
                    ? "↑↓ filter  ·  ↵ choose  ·  esc close menu"
                    : root.footerText
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Filter burger dropdown
        Rectangle {
            visible: root.filterMenuOpen && root.hasFilter
            width: Math.max(160, filterCol.implicitWidth + 16)
            height: filterCol.implicitHeight + 12
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 72
            anchors.rightMargin: 14
            radius: Theme.radiusMd
            color: Theme.surface
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
                                return Theme.glassTileActiveHover
                            if (modelData.value === root.filterValue)
                                return Theme.glassSurfaceHover
                            return "transparent"
                        }
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
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
