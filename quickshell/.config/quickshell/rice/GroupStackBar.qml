pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Quickshell stack strip: inset to window rounding, gap above frame, segmented.
Scope {
    id: root

    property var segments: []

    Process {
        id: probe
        running: true
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/group-stack-bar.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = text.trim()
                    if (!raw || raw === "{}") {
                        root.segments = []
                        return
                    }
                    const data = JSON.parse(raw)
                    root.segments = data.segments || []
                } catch (e) {
                    root.segments = []
                }
            }
        }
    }

    Timer {
        interval: root.segments.length > 0 ? 50 : 150
        running: true
        repeat: true
        onTriggered: {
            probe.running = false
            probe.running = true
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-groupstack"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            visible: root.segments.length > 0

            Repeater {
                model: root.segments

                Rectangle {
                    required property var modelData
                    // Script already emits panel-local coordinates
                    x: modelData.x
                    y: modelData.y
                    width: Math.max(2, modelData.w)
                    height: Math.max(3, modelData.h)
                    radius: 1
                    color: modelData.active ? Theme.primary
                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                }
            }
        }
    }
}
