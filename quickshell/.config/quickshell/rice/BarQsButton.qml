import QtQuick
import QtQuick.Layouts
import "ds" as DS

BarIsland {
    id: root
    clickable: true

    content: [
        RiceIcon {
            name: "view-grid"
            fallback: "open-menu"
            implicitSize: 16
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            tint: DS.Tokens.textIcon
        }
    ]
}
