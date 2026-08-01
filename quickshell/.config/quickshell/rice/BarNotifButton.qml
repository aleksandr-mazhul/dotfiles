import QtQuick
import QtQuick.Layouts

BarIsland {
    id: root
    clickable: true

    property bool muted: false
    property int unread: 0

    Text {
        text: root.muted ? "󰂛" : (root.unread > 0 ? "󰂚" : "󰂜")
        color: root.muted ? Theme.textMuted : Theme.text
        font.pixelSize: 16
        font.family: "JetBrainsMono Nerd Font, JetBrains Mono, sans-serif"
    }

    Rectangle {
        visible: root.unread > 0 && !root.muted
        Layout.preferredWidth: Math.max(16, badge.implicitWidth + 6)
        Layout.preferredHeight: 16
        radius: 8
        color: Theme.primary

        Text {
            id: badge
            anchors.centerIn: parent
            text: root.unread > 99 ? "99+" : String(root.unread)
            color: Theme.textOnAccent
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
        }
    }
}
