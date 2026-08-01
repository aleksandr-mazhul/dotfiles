pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Io

Scope {
    id: root

    property real osdValue: 0
    property string osdIcon: "󰕾"
    property bool osdVisible: false
    property int brightLast: -1
    property int brightMax: 0

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    function showVolume() {
        const sink = Pipewire.defaultAudioSink
        if (!sink || !sink.audio)
            return
        const muted = sink.audio.muted
        const vol = sink.audio.volume
        osdValue = muted ? 0 : vol
        if (muted)
            osdIcon = "󰝟"
        else if (vol < 0.34)
            osdIcon = "󰕿"
        else if (vol < 0.67)
            osdIcon = "󰖀"
        else
            osdIcon = "󰕾"
        osdVisible = true
        hideTimer.restart()
    }

    function showBrightness(value) {
        osdValue = Math.max(0, Math.min(1, value))
        osdIcon = "󰃠"
        osdVisible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: root.osdVisible = false
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        function onVolumeChanged() { root.showVolume() }
        function onMutedChanged() { root.showVolume() }
    }

    Process {
        id: brightMaxProc
        running: true
        command: ["bash", "-lc", "brightnessctl -m max 2>/dev/null || echo 255"]
        stdout: StdioCollector {
            onStreamFinished: root.brightMax = parseInt(text.trim() || "255", 10) || 255
        }
    }

    Process {
        id: brightWatch
        running: true
        command: ["bash", "-lc", "while true; do brightnessctl -m get 2>/dev/null || echo 0; sleep 0.5; done"]
        stdout: SplitParser {
            onRead: data => {
                const v = parseInt(String(data).trim(), 10)
                if (isNaN(v))
                    return
                if (root.brightLast >= 0 && v !== root.brightLast && root.brightMax > 0)
                    root.showBrightness(v / root.brightMax)
                root.brightLast = v
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.osdVisible
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            implicitWidth: 220
            implicitHeight: 56
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-osd"

            anchors {
                bottom: true
            }
            margins {
                bottom: 48
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.background
                radius: Theme.radiusLg
                border.width: 1
                border.color: Theme.borderSubtle
                opacity: 0.96

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: root.osdIcon
                        color: Theme.text
                        font.pixelSize: 20
                        font.family: "JetBrainsMono Nerd Font, JetBrains Mono, sans-serif"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4
                        color: Theme.surfaceContainer

                        Rectangle {
                            width: parent.width * root.osdValue
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                        }
                    }

                    Text {
                        text: Math.round(root.osdValue * 100) + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        Layout.preferredWidth: 36
                    }
                }
            }
        }
    }
}
