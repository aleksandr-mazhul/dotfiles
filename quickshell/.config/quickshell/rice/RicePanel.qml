import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

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

    // Stay visible through the close animation so it doesn't vanish mid-fade.
    visible: open || closeAnim.running
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.namespace: "rice-panel"
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
        closeAnim.stop()
        open = true
        selectedIndex = 0
        searchField.text = ""
        filterMenuOpen = false
        panelOpened()
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
        closeAnim.play()
        panelClosed()
    }

    // Shared Super+P entry: toggle filter if open; otherwise open with filter menu.
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

    function moveSelection(delta) {
        if (!model || model.length === 0)
            return
        selectedIndex = (selectedIndex + delta + model.length) % model.length
        listView.positionViewAtIndex(selectedIndex, ListView.Contain)
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
        filterHighlight = (filterHighlight + delta + n) % n
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

    onModelChanged: clampSelection()
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
        opacity: root.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? Theme.menuAnimMs : Theme.menuCloseMs
                easing.type: root.open ? Easing.OutCubic : Easing.InCubic
            }
        }
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
        color: Theme.glassBackground
        border.color: Theme.glassBorder
        border.width: 1
        transformOrigin: Item.Center
        opacity: 1
        scale: 1

        RiceOpenAnim {
            id: openAnim
            target: panel
            fromScale: 0.97
        }

        RiceCloseAnim {
            id: closeAnim
            target: panel
            toScale: 0.97
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
                    Layout.preferredWidth: Math.max(110, filterPillLabel.implicitWidth + 36)
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

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.model
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
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
            color: Theme.glassBackground
            border.color: Theme.glassBorder
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
