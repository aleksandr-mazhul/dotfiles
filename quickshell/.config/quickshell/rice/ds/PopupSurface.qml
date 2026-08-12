import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Popup Surface pattern: one floating glass sheet, no fullscreen dim behind
// (anti-pattern #6 — dim kills the material). Owns window plumbing: layer,
// focus, open/close, click-away, OverlayHub registration.
// Content is a single child that must define implicitHeight and fill width.
PanelWindow {
    id: root

    property bool open: false
    readonly property bool surfaceActive: open
    property int surfaceWidth: 640
    // Top edge of the pane as a fraction of screen height (stable position;
    // the pane grows downward) — realizes launcher.position.y.
    property real anchorY: 0.22
    // function(event) -> bool; runs before the default Esc-close.
    property var keyHandler: null

    default property alias content: inner.data
    readonly property Item paneItem: pane

    // "opened"/"closed" collide with superclass signals — hence the popup prefix.
    signal popupOpened()
    signal popupClosed()

    visible: open
    color: "transparent"
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-popup"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    Component.onCompleted: OverlayHub.register(root)

    function toggle() {
        if (open)
            close()
        else
            show()
    }

    function show() {
        OverlayHub.closeOthers(root)
        open = true
        popupOpened()
        openAnim.play()
    }

    function close() {
        if (!open)
            return
        openAnim.stop()
        open = false
        pane.opacity = 1
        pane.scale = 1
        popupClosed()
    }

    function handleKey(event) {
        if (typeof keyHandler === "function" && keyHandler(event))
            return true
        if (event.key === Qt.Key_Escape) {
            close()
            return true
        }
        return false
    }

    // Click-away closes; sits behind the pane.
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Item {
        id: pane
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * root.anchorY)
        width: root.surfaceWidth
        height: inner.children.length > 0 ? inner.children[0].implicitHeight : 0
        transformOrigin: Item.Center

        RiceOpenAnim {
            id: openAnim
            target: pane
            fromScale: 0.98
        }

        GlassSurface {
            anchors.fill: parent

            Item {
                id: inner
                anchors.fill: parent
            }
        }
    }
}
