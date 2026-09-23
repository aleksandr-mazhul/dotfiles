pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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

    function reprobe() {
        probe.running = false
        probe.running = true
    }

    // Event-driven: re-run the probe when Hyprland reports focus / group /
    // window / workspace changes, coalescing bursts into one run.
    readonly property var probeEvents: ({
        "activewindowv2": true, "changegroupactive": true,
        "moveintogroup": true, "moveoutofgroup": true, "togglegroup": true,
        "lockgroups": true, "ignoregrouplock": true,
        "openwindow": true, "closewindow": true,
        "movewindow": true, "movewindowv2": true,
        "changefloatingmode": true, "fullscreen": true,
        "workspace": true, "workspacev2": true,
        "focusedmon": true, "focusedmonv2": true,
        "moveworkspace": true, "moveworkspacev2": true,
        "monitoradded": true, "monitoraddedv2": true,
        "monitorremoved": true, "monitorremovedv2": true,
        "configreloaded": true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.probeEvents[event.name] === true)
                probeDebounce.restart()
        }
    }

    Timer {
        id: probeDebounce
        interval: 30
        repeat: false
        onTriggered: root.reprobe()
    }

    // Safety net: geometry changes without an IPC event (resize / drag of the
    // grouped window) still get picked up while a strip is visible.
    Timer {
        interval: root.segments.length > 0 ? 500 : 5000
        running: true
        repeat: true
        onTriggered: root.reprobe()
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
                    color: modelData.active ? Qt.rgba(1, 1, 1, 0.94)
                        : Qt.rgba(1, 1, 1, 0.38)
                }
            }
        }
    }
}
