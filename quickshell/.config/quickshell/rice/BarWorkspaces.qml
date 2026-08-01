import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

BarIsland {
    id: root

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property var modelData
            visible: modelData && modelData.id > 0
            readonly property bool focused: modelData && modelData.focused

            Layout.preferredHeight: Theme.barHeight - Theme.barIslandPadV * 2
            Layout.preferredWidth: visible ? Math.max(22, label.implicitWidth + 12) : 0
            radius: 12
            color: focused ? Theme.primary : "transparent"

            Text {
                id: label
                anchors.centerIn: parent
                text: modelData ? (modelData.name || String(modelData.id)) : ""
                color: focused ? Theme.textOnAccent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.bold: focused
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (modelData) modelData.activate()
            }
        }
    }
}
