import QtQuick
import QtQuick.Layouts
import "ds" as DS

BarIsland {
    id: root
    clickable: true

    property bool muted: false
    property int unread: 0

    content: [
        RiceIcon {
            customSource: Qt.resolvedUrl(root.muted ? "assets/notif-bell-off.svg" : "assets/notif-bell.svg")
            tint: DS.Tokens.textIcon
            struck: false
            implicitSize: 16
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
        },
        Rectangle {
            visible: root.unread > 0 && !root.muted
            Layout.preferredWidth: Math.max(16, badge.implicitWidth + 6)
            Layout.preferredHeight: 16
            radius: 8
            color: DS.Tokens.raisedStrong
            border.width: 1
            border.color: DS.Tokens.raisedRim

            DS.QuietText {
                id: badge
                anchors.centerIn: parent
                text: root.unread > 99 ? "99+" : String(root.unread)
                color: DS.Tokens.textPrimary
                font.family: DS.Tokens.fontUi
                font.pixelSize: 10
                fontBold: true
            }
        }
    ]
}
