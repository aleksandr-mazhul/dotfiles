pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Scene luminance → contrast compensation (0 = dark, 1 = very bright).
// luma = max(wallpaper, live region under the popup). Does not tint glass.
Item {
    id: root

    width: 0
    height: 0
    visible: false

    property real luma: 0.22
    property real contrast: 0
    property string regionGeom: ""

    function contrastFromLuma(L) {
        const lo = 0.30
        const hi = 0.68
        const t = Math.min(1, Math.max(0, (L - lo) / (hi - lo)))
        return t * t * (3 - 2 * t)
    }

    function refresh(geom) {
        if (typeof geom === "string")
            root.regionGeom = geom
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
        command: root.regionGeom.length > 0
            ? ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-luma.sh", root.regionGeom]
            : ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-luma.sh"]
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
