pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper luminance → contrast compensation (0 = dark, 1 = very bright).
// Does not tint the glass; Tokens map this into localized black scrims.
Item {
    id: root

    width: 0
    height: 0
    visible: false

    property real luma: 0.22
    property real contrast: 0

    function contrastFromLuma(L) {
        const lo = 0.30
        const hi = 0.68
        const t = Math.min(1, Math.max(0, (L - lo) / (hi - lo)))
        return t * t * (3 - 2 * t)
    }

    function refresh() {
        if (probe.running)
            probe.running = false
        probe.running = true
    }

    Behavior on contrast {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    Process {
        id: probe
        running: false
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-luma.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(String(text).trim())
                if (isNaN(v))
                    return
                root.luma = Math.min(1, Math.max(0, v))
                root.contrast = root.contrastFromLuma(root.luma)
            }
        }
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.config/waypaper/config.ini`
        blockLoading: false
        printErrors: false
        watchChanges: true
        onFileChanged: root.refresh()
    }

    Component.onCompleted: refresh()
}
