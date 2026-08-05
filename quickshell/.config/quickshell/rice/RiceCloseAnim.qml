import QtQuick

// Smooth close dismiss — fade + slight scale down, synced with dim.
// Keep `visible: open || closeAnim.running` on the PanelWindow.
ParallelAnimation {
    id: root

    property Item target
    property Item dimTarget
    property int duration: Theme.menuCloseMs
    property real toScale: 0.98

    NumberAnimation {
        target: root.target
        property: "opacity"
        to: 0
        duration: root.duration
        easing.type: Easing.InCubic
    }
    NumberAnimation {
        target: root.target
        property: "scale"
        to: root.toScale
        duration: root.duration
        easing.type: Easing.InCubic
    }
    NumberAnimation {
        target: root.dimTarget
        property: "opacity"
        to: 0
        duration: root.duration
        easing.type: Easing.InCubic
    }

    function play() {
        if (!root.target)
            return
        root.stop()
        root.restart()
    }
}
