pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Io
import "ds" as DS

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
        osdValue = vol
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
        command: ["bash", "-c", "~/.config/hypr/scripts/qs-brightness.sh max"]
        stdout: StdioCollector {
            onStreamFinished: root.brightMax = parseInt(text.trim() || "100", 10) || 100
        }
    }

    // qs-brightness.sh calls `qs ipc call brightness level <pct>` the moment a
    // key or slider changes the target, before the slow DDC write. Watching its
    // cache file lost updates (truncate + write fired two events; reloads were
    // dropped), so the OSD often never appeared.
    IpcHandler {
        target: "brightness"
        function level(pct: int): void {
            root.brightLast = pct
            root.showBrightness(pct / (root.brightMax > 0 ? root.brightMax : 100))
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

            DS.GlassSurface {
                anchors.fill: parent
                radius: DS.Tokens.radiusSurface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.leftMargin: DS.Tokens.paddingFieldX
                    anchors.rightMargin: DS.Tokens.paddingFieldX
                    spacing: DS.Tokens.gapInline

                    RiceIcon {
                        name: root.osdIconName
                        fallback: "audio-volume-high"
                        customSource: root.osdCustomSource
                        struck: root.osdStruck
                        tint: DS.Tokens.textIcon
                        halo: true
                        haloColor: DS.Tokens.iconHalo
                        implicitSize: 22
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4
                        color: DS.Tokens.fieldFill

                        Rectangle {
                            width: parent.width * root.osdValue
                            height: parent.height
                            radius: parent.radius
                            color: DS.Tokens.raisedStrong
                            border.width: 1
                            border.color: DS.Tokens.raisedRim
                        }
                    }

                    DS.QuietText {
                        text: Math.round(root.osdValue * 100) + "%"
                        color: DS.Tokens.textPrimary
                        font.family: DS.Tokens.fontUi
                        font.pixelSize: DS.Tokens.fontSizeSm
                        fontWeight: Font.Normal
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 36
                    }
                }
            }
        }
    }
}
