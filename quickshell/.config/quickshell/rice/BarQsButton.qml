import QtQuick
import QtQuick.Layouts

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
        }
    ]
}
