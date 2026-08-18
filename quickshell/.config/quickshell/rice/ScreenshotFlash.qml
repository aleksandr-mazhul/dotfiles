pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool flashing: false

    function flash() {
        flashing = false
        flashing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 160
        onTriggered: root.flashing = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.flashing || flashRect.opacity > 0.02
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-screenshot-flash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            Rectangle {
                id: flashRect
                anchors.fill: parent
                color: Qt.rgba(1, 1, 1, 0.25)
                opacity: root.flashing ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
