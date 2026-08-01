import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

BarIsland {
    id: root
    // Quickshell ObjectModel uses .values, not .count — .count kept the island
    // hidden while SNI still registered, which stole bar button clicks.
    visible: SystemTray.items.values.length > 0

    content: [
        Repeater {
            model: SystemTray.items

            delegate: MouseArea {
                id: trayItem
                required property var modelData

                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    sourceSize.width: 18
                    sourceSize.height: 18
                    source: trayItem.modelData.icon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }

                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        modelData.secondaryActivate()
                        return
                    }
                    if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                        if (modelData.hasMenu)
                            modelData.display(QsWindow.window, trayItem.width / 2, trayItem.height)
                        return
                    }
                    modelData.activate()
                }
            }
        }
    ]
}
