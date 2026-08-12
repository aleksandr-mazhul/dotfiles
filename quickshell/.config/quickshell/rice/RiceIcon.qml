import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

// Chrome icons prefer our local mono SVG atlas (foundation/icons.md).
// Theme icons are a fallback only — never show Quickshell's magenta
// "missing texture" checkers in the shell UI.
Item {
    id: root

    property string name: ""
    property string fallback: "dialog-information"
    property url customSource: ""
    property bool struck: false
    property int implicitSize: 18
    property color tint: Theme.text

    // Theme-name → local chrome glyph. Keep in sync with assets/icon-*.svg.
    readonly property var chromeMap: ({
        "network-wired": "icon-network.svg",
        "network-wireless": "icon-network.svg",
        "preferences-system-network": "icon-network.svg",
        "bluetooth": "icon-bluetooth.svg",
        "network-vpn": "cmd-vpn.svg",
        "view-refresh": "icon-refresh.svg",
        "system-shutdown": "icon-power.svg",
        "system-reboot": "icon-reboot.svg",
        "system-suspend": "icon-suspend.svg",
        "system-lock-screen": "icon-lock.svg",
        "system-log-out": "icon-logout.svg",
        "audio-volume-high": "icon-volume.svg",
        "audio-volume-medium": "icon-volume.svg",
        "audio-volume-low": "icon-volume.svg",
        "audio-volume-muted": "icon-volume-muted.svg",
        "audio-headphones": "icon-headphones.svg",
        "audio-input-microphone-high": "icon-mic.svg",
        "audio-input-microphone-muted": "icon-mic-muted.svg",
        "go-down": "chevron-down.svg",
        "go-up": "chevron-down.svg",
        "go-next": "chevron-right.svg",
        "go-previous": "chevron-left.svg",
        "dialog-information": "icon-info.svg",
        "edit-find": "search.svg",
        "search": "search.svg"
    })

    readonly property string chromeFile: {
        if (customSource.toString().length > 0)
            return ""
        if (name && chromeMap[name])
            return chromeMap[name]
        if (fallback && chromeMap[fallback])
            return chromeMap[fallback]
        return ""
    }
    readonly property bool useCustom: customSource.toString().length > 0 || chromeFile.length > 0
    readonly property url resolvedCustom: customSource.toString().length > 0
        ? customSource
        : (chromeFile.length > 0 ? Qt.resolvedUrl("assets/" + chromeFile) : "")

    width: implicitSize
    height: implicitSize

    // Theme path only when we have no local chrome glyph.
    // check=true → empty string instead of missing-texture if absent.
    IconImage {
        id: img
        anchors.fill: parent
        asynchronous: true
        mipmap: true
        implicitSize: root.implicitSize
        visible: !root.useCustom && status !== Image.Error && status !== Image.Null
        source: root.useCustom ? "" : (root.name ? Quickshell.iconPath(root.name, true) : "")
    }

    // Quiet placeholder if theme icon is missing and no chrome map entry exists.
    Rectangle {
        anchors.centerIn: parent
        visible: !root.useCustom && (img.status === Image.Error || img.status === Image.Null || !root.name)
        width: Math.max(4, root.implicitSize * 0.28)
        height: width
        radius: width / 2
        color: root.tint
        opacity: 0.35
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
            source: root.resolvedCustom
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
