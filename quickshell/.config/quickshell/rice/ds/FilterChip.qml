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
        color: root.active ? GlassGrade.filmStrong : GlassGrade.film
        border.width: 1
        border.color: root.menuOpen ? GlassGrade.focusRim : GlassGrade.hairline
    }

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 3

        QuietText {
            text: root.label
            color: root.active ? GlassGrade.textPrimary : GlassGrade.textSecondary
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.fontSizeSm - 1
            width: implicitWidth
            height: implicitHeight
            anchors.verticalCenter: parent.verticalCenter
        }
        QuietText {
            text: "˅"
            color: GlassGrade.textTertiary
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
