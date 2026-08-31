import QtQuick

// Clipboard-style filter pill — shared by Clipboard, Wallpaper, VPN, etc.
Item {
    id: root

    property string label: "All"
    property bool menuOpen: false
    signal clicked()

    implicitWidth: chipRow.implicitWidth + 14
    implicitHeight: 22
    width: implicitWidth
    height: implicitHeight

    readonly property bool active: menuOpen || chipMouse.containsMouse

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Qt.rgba(1, 1, 1, (root.active ? 0.12 : 0.07)
            * (1 - AdaptiveContrast.contrast * 0.75))
        border.width: 1
        border.color: root.menuOpen
            ? Tokens.focusRim
            : Qt.rgba(1, 1, 1, 0.22 + AdaptiveContrast.contrast * 0.10)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(parent.height * 0.45)
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 3

        QuietText {
            text: root.label
            color: root.active ? Tokens.textPrimary : Tokens.textSecondary
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.fontSizeSm - 1
            width: implicitWidth
            height: implicitHeight
            anchors.verticalCenter: parent.verticalCenter
        }
        QuietText {
            text: "˅"
            color: Tokens.textTertiary
            font.family: Tokens.fontUi
            font.pixelSize: 10
            width: implicitWidth
            height: implicitHeight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
