import QtQuick

// Smooth open reveal — fade + soft scale (no overshoot; OutBack feels jerky on 165Hz).
ParallelAnimation {
    id: root

    property Item target
    property Item dimTarget
    property int duration: Theme.menuAnimMs
    property real fromScale: 0.98

    NumberAnimation {
        target: root.target
        property: "opacity"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        target: root.target
        property: "scale"
        from: root.fromScale
        to: 1
        duration: root.duration
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        target: root.dimTarget
        property: "opacity"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.OutCubic
    }

    function play() {
        if (!root.target)
            return
        root.stop()
        root.target.opacity = 0
        root.target.scale = root.fromScale
        if (root.dimTarget)
            root.dimTarget.opacity = 0
        root.restart()
    }
}
