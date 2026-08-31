import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "ds" as DS

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
        DS.QuietText {
            Layout.fillWidth: true
            text: root.titleText
            color: DS.Tokens.textPrimary
            font.family: DS.Tokens.fontUi
            font.pixelSize: DS.Tokens.fontSizeSm
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    ]
}
