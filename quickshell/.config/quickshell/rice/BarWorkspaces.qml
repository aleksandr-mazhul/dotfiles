import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "ds" as DS

BarIsland {
    id: root

    content: [
        Repeater {
            model: Hyprland.workspaces

            delegate: Rectangle {
                id: chip
                required property var modelData
                visible: modelData && modelData.id > 0
                readonly property bool focused: modelData && modelData.focused

                Layout.preferredHeight: Theme.barHeight - Theme.barIslandPadV * 2
                Layout.preferredWidth: visible ? Math.max(22, label.implicitWidth + 12) : 0
                radius: DS.Tokens.innerRadius(root.islandRadius, Theme.barIslandPadV)
                color: focused ? DS.Tokens.raisedStrong
                    : (chipMouse.containsMouse ? DS.Tokens.raised : "transparent")
                border.width: (focused || chipMouse.containsMouse) ? 1 : 0
                border.color: DS.Tokens.raisedRim

                DS.QuietText {
                    id: label
                    anchors.centerIn: parent
                    text: modelData ? (modelData.name || String(modelData.id)) : ""
                    color: focused ? DS.Tokens.textPrimary : DS.Tokens.textSecondary
                    font.family: DS.Tokens.fontUi
                    font.pixelSize: DS.Tokens.fontSizeSm
                    fontBold: focused
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    z: 2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (modelData) modelData.activate()
                }
            }
        }
    ]
}
