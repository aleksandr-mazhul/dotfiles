import QtQuick

// Short open-only reveal for rice menus (no layer resize — keeps 165Hz smooth).
ParallelAnimation {
    id: root

    property Item target
    property int duration: Theme.menuAnimMs
    property real fromScale: 0.97

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
        easing.type: Easing.OutBack
        easing.overshoot: Theme.menuOvershoot
    }

    function play() {
        if (!root.target)
            return
        root.stop()
        root.target.opacity = 0
        root.target.scale = root.fromScale
        root.restart()
    }
}
