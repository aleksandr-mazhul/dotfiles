import QtQuick
import QtQuick.Layouts

BarIsland {
    id: root
    clickable: true

    property bool active: false

    content: [
        RiceIcon {
            name: root.active ? "preferences-other" : "view-grid"
            fallback: "open-menu"
            implicitSize: 16
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
        }
    ]
}
