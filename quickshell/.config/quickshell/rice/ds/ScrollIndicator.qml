import QtQuick

// Thin monochrome scroll position hint — no permanent chrome, no accent.
Item {
    id: root

    property Flickable view: null

    readonly property bool needed: view && view.contentHeight > view.height + 2
    visible: needed
    width: 4

    Rectangle {
        readonly property real ratio: root.view ? root.view.height / Math.max(1, root.view.contentHeight) : 0
        readonly property real range: Math.max(1, root.view ? root.view.contentHeight - root.view.height : 1)

        width: parent.width
        radius: 2
        height: Math.max(24, root.height * ratio)
        y: (root.height - height) * Math.max(0, Math.min(1, root.view ? root.view.contentY / range : 0))
        color: Tokens.textTertiary
        opacity: 0.5
    }
}
