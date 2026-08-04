import QtQuick

// Quick close-only dismiss for rice menus — fade + scale down, no overshoot.
// Pair with RiceOpenAnim: keep `visible: open || closeAnim.running` on the
// PanelWindow so the layer doesn't vanish mid-animation.
ParallelAnimation {
    id: root

    property Item target
    property int duration: Theme.menuCloseMs
    property real toScale: 0.96

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

    function play() {
        if (!root.target)
            return
        root.stop()
        root.restart()
    }
}
