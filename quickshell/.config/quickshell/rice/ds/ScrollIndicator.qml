import QtQuick

// Thin monochrome scroll position hint — no permanent chrome, no accent.
Item {
    id: root

    property Flickable view: null

    readonly property bool needed: view && view.contentHeight > view.height + 2
    visible: needed
    width: 3

    // Pin the thumb to the top at origin. ListView originY is often non-zero,
    // so contentY/range alone can report "end of list" while the view is at the top.
    readonly property real progress: {
        if (!view)
            return 0
        if (view.atYBeginning)
            return 0
        const origin = view.originY
        const cy = view.contentY
        if (!(cy === cy) || !(origin === origin))
            return 0
        if (cy <= origin + 1)
            return 0
        const range = Math.max(1, view.contentHeight - view.height)
        return Math.max(0, Math.min(1, (cy - origin) / range))
    }

    Rectangle {
        readonly property real ratio: root.view ? root.view.height / Math.max(1, root.view.contentHeight) : 0

        width: parent.width
        radius: 2
        height: Math.max(24, root.height * Math.max(0.05, Math.min(1, ratio)))
        y: (root.height - height) * root.progress
        color: Qt.rgba(1, 1, 1, 0.40)
        opacity: 0.55
    }
}
