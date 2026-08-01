import QtQuick
import QtQuick.Layouts
import Quickshell

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
    property int panelMaxHeight: Theme.panelMaxHeight
    property string footerText: "↑↓ move  ·  ↵ select  ·  esc close"
    property Component rowDelegate
    property bool registerWithHub: true

    readonly property alias listView: listView
    readonly property alias searchField: searchField

    signal activated(var item, int index)
    signal panelOpened()
    signal panelClosed()
    signal queryChanged(string text)

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
        searchField.text = ""
        panelOpened()
        Qt.callLater(() => {
            if (showSearch)
                searchField.forceActiveFocus()
            else
                focusCatcher.forceActiveFocus()
        })
    }

    function close() {
        if (!open)
            return
        open = false
        searchField.text = ""
        panelClosed()
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

    onModelChanged: clampSelection()

    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: root.open && !root.showSearch

        Keys.onPressed: event => {
            if (!root.open)
                return
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                root.moveSelection(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                root.moveSelection(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activateSelected()
                event.accepted = true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.40)
        z: -1
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: panel
        width: root.panelWidth
        height: Math.min(
            root.panelMaxHeight,
            (root.showSearch ? 132 : 88) + Math.min(Math.max(model ? model.length : 1, 1), root.maxVisible) * root.itemHeight
        )
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.surface
        border.color: Theme.outline
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radiusLg - 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.showSearch)
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
                    color: Theme.onSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.countText.length > 0
                    text: root.countText
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
            }

            Rectangle {
                visible: root.showSearch
                Layout.fillWidth: true
                height: 42
                radius: Theme.radiusMd
                color: Theme.surfaceContainer
                border.color: searchField.activeFocus ? Theme.primary : Theme.outline
                border.width: 1

                TextInput {
                    id: searchField
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.onSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: root.searchPlaceholder
                        color: Theme.outline
                        font: searchField.font
                        visible: searchField.text.length === 0
                    }

                    onTextChanged: root.queryChanged(text)

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activateSelected()
                            event.accepted = true
                        }
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
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            Text {
                text: root.footerText
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
