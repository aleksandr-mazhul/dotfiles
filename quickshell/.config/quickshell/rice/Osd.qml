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
    property string osdIconName: "audio-volume-high"
    property url osdCustomSource: ""
    property bool osdStruck: false
    property bool osdVisible: false
    property int brightLast: -1
    property int brightMax: 0

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    function sinkLooksLikeHeadphones(sink) {
        if (!sink)
            return false
        const blob = [sink.name, sink.nickname, sink.description].filter(Boolean).join(" ").toLowerCase()
        // Same as Quick Settings: Logitech USB dongle / JBL Flip is a speaker, not cans.
        if (/jbl|flip\s*\d|logitech.*usb.?headset|usb headset/.test(blob))
            return false
        return /headphone|earphone|earbuds|airpods|(^|[^a-z])headset([^a-z]|$)/.test(blob)
    }

    function volumeIconName(vol, headphones, muted) {
        if (muted && !headphones)
            return "audio-volume-muted"
        if (headphones)
            return "audio-headphones"
        if (vol < 0.34)
            return "audio-volume-low"
        if (vol < 0.67)
            return "audio-volume-medium"
        return "audio-volume-high"
    }

    function showVolume() {
        const sink = Pipewire.defaultAudioSink
        if (!sink || !sink.audio)
            return
        const muted = !!sink.audio.muted
        const vol = sink.audio.volume
        const headphones = sinkLooksLikeHeadphones(sink)
        osdValue = muted ? 0 : vol
        osdIconName = volumeIconName(vol, headphones, muted)
        osdCustomSource = ""
        osdStruck = muted && headphones
        osdVisible = true
        hideTimer.restart()
    }

    function showBrightness(value) {
        osdValue = Math.max(0, Math.min(1, value))
        osdIconName = ""
        osdCustomSource = Qt.resolvedUrl("assets/brightness-sun.svg")
        osdStruck = false
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
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-brightness.sh max"]
        stdout: StdioCollector {
            onStreamFinished: root.brightMax = parseInt(text.trim() || "100", 10) || 100
        }
    }

    // Watch brightness cache written by qs-brightness.sh (never poll ddcutil).
    Process {
        id: brightWatch
        running: true
        command: [
            "bash", "-lc",
            "while true; do "
                + "for f in \"$XDG_RUNTIME_DIR/rice/brightness.pct\" \"$HOME/.cache/rice/brightness.pct\"; do "
                + "if [ -f \"$f\" ]; then cat \"$f\"; break; fi; "
                + "done || echo 0; "
                + "sleep 0.5; "
                + "done"
        ]
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
            implicitWidth: 240
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

                    RiceIcon {
                        name: root.osdIconName
                        fallback: "audio-volume-high"
                        customSource: root.osdCustomSource
                        struck: root.osdStruck
                        implicitSize: 22
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
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
