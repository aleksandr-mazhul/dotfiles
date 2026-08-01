import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

BarIsland {
    id: root
    visible: titleText.length > 0

    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string titleText: {
        const t = toplevel && toplevel.wayland ? (toplevel.wayland.title || "") : ""
        if (!t)
            return ""
        const cut = t.split(/\s+[—\-–|]\s+/)[0].trim()
        return cut.length > 28 ? cut.slice(0, 27) + "…" : cut
    }

    content: [
        Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 4
            color: Theme.primary
        },
        Text {
            Layout.fillWidth: true
            text: root.titleText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    ]
}
