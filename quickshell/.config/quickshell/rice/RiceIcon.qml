import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

// Papirus icons via iconPath, or a local mono SVG via customSource (tinted to Theme.text).
Item {
    id: root

    property string name: ""
    property string fallback: "dialog-information"
    property url customSource: ""
    property bool struck: false
    property int implicitSize: 18
    property color tint: Theme.text
    readonly property bool useCustom: customSource.toString().length > 0

    width: implicitSize
    height: implicitSize

    IconImage {
        id: img
        anchors.fill: parent
        asynchronous: true
        mipmap: true
        implicitSize: root.implicitSize
        visible: !root.useCustom
        source: root.useCustom ? "" : (root.name ? Quickshell.iconPath(root.name, root.fallback) : "")
    }

    Item {
        anchors.fill: parent
        visible: root.useCustom

        IconImage {
            id: mono
            anchors.fill: parent
            asynchronous: true
            mipmap: true
            implicitSize: root.implicitSize
            visible: false
            source: root.customSource
        }

        ColorOverlay {
            anchors.fill: parent
            source: mono
            color: root.tint
            cached: true
            Behavior on color {
                ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
            }
        }
    }

    Rectangle {
        visible: root.struck
        anchors.centerIn: parent
        width: Math.max(2, root.implicitSize * 1.2)
        height: Math.max(2, root.implicitSize * 0.14)
        radius: height / 2
        rotation: -42
        color: Theme.error
        border.width: 1
        border.color: Theme.background
        z: 2
    }
}
