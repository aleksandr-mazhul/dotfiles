import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

BarIsland {
    id: root
    visible: SystemTray.items.count > 0

    Repeater {
        model: SystemTray.items

        delegate: Item {
            required property var modelData
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: modelData.icon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton && modelData.hasMenu)
                        modelData.display(root, width / 2, height)
                    else
                        modelData.activate()
                }
            }
        }
    }
}
