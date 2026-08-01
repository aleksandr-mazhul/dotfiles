import QtQuick
import QtQuick.Layouts

BarIsland {
    id: root
    clickable: true

    property bool active: false

    Text {
        text: root.active ? "󰒓" : "󰕾"
        color: Theme.primary
        font.pixelSize: 16
        font.family: "JetBrainsMono Nerd Font, JetBrains Mono, sans-serif"
    }
}
