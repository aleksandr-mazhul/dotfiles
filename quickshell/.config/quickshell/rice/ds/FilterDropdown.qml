import QtQuick

// Dropdown for SearchListPopup / Clipboard type+category filter.
Item {
    id: root

    property var options: []
    property int highlight: 0
    property string currentValue: ""
    signal picked(int index)

    implicitWidth: 180
    implicitHeight: col.implicitHeight + 12
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusField
        color: Tokens.fieldFill
        border.width: 1
        border.color: Tokens.focusRim
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusField
        color: Tokens.paneScrim
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 2

        Repeater {
            model: root.options

            delegate: Item {
                required property var modelData
                required property int index
                width: col.width
                height: 34

                SelectionPill {
                    anchors.fill: parent
                    hovered: rowMouse.containsMouse
                    selected: index === root.highlight || (modelData && modelData.value === root.currentValue)
                }

                QuietText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label || ""
                    color: Tokens.textPrimary
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.fontSizeSm
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.highlight = index
                    onClicked: root.picked(index)
                }
            }
        }
    }
}
