import QtQuick
import QtQuick.Layouts

BarIsland {
    id: root
    clickable: true

    property string timeText: ""

    Text {
        text: root.timeText
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSm
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const d = new Date()
            const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            const dd = String(d.getDate()).padStart(2, "0")
            const hh = String(d.getHours()).padStart(2, "0")
            const mm = String(d.getMinutes()).padStart(2, "0")
            root.timeText = days[d.getDay()] + " " + dd + " " + hh + ":" + mm
        }
    }
}
