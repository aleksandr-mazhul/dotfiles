import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
    property bool parked: false
    // Optional: refocus the active input after compositor focus is restored.
    property var refocusHandler: null

    default property alias content: inner.data
    readonly property Item paneItem: pane

    // "opened"/"closed" collide with superclass signals — hence the popup prefix.
    signal popupOpened()
    signal popupClosed()
    signal resumed()

    visible: open
    color: "transparent"
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-popup"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    Component.onCompleted: OverlayHub.register(root)

    function grabFocus() {
        Qt.callLater(() => {
            root.forceActiveFocus()
            if (typeof refocusHandler === "function")
                refocusHandler()
        })
    }

    function toggle() {
        if (open)
            close()
        else
            show()
    }

    function present() {
        AdaptiveContrast.refresh()
        parked = false
        open = true
        popupOpened()
        openAnim.play()
        grabFocus()
    }

    function show() {
        OverlayHub.closeOthers(root)
        present()
    }

    function hide() {
        const notify = open || parked
        parked = false
        if (!notify)
            return
        openAnim.stop()
        open = false
        pane.opacity = 1
        pane.scale = 1
        popupClosed()
    }

    function park() {
        if (!open)
            return
        parked = true
        openAnim.stop()
        open = false
        pane.opacity = 1
        pane.scale = 1
    }

    function resume() {
        parked = false
        AdaptiveContrast.refresh()
        open = true
        resumed()
        openAnim.play()
        grabFocus()
    }

    function close() {
        hide()
        OverlayHub.dropStack(root)
    }

    function popView() {
        return false
    }

    function handleKey(event) {
        if (typeof keyHandler === "function" && keyHandler(event))
            return true
        if (event.key === Qt.Key_Escape) {
            if (typeof root.popView === "function" && root.popView())
                return true
            root.close()
            return true
        }
        return false
    }

    // Click-away dismisses the whole stack (Raycast: outside click closes).
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Hyprland: keep keyboard on this popup across workspace switches.
    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: root.open && !root.parked
        onCleared: {
            // Outside click clears the grab — dismiss unless already closing.
            if (root.open)
                root.close()
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            if (!root.open || root.parked)
                return
            // Re-arm after workspace switch (compositor may briefly drop layer focus).
            focusGrab.active = false
            Qt.callLater(() => {
                if (!root.open)
                    return
                focusGrab.active = true
                root.grabFocus()
            })
        }
    }

    Item {
        id: pane
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * root.anchorY)
        width: Math.min(root.surfaceWidth, Math.max(480, root.width - 80))
        height: {
            const kids = inner.children
            for (let i = 0; i < kids.length; i++) {
                const c = kids[i]
                if (c.visible)
                    return Math.max(0, c.implicitHeight)
            }
            return 0
        }
        transformOrigin: Item.Center
        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return
            if (root.handleKey(event))
                event.accepted = true
        }

        RiceOpenAnim {
            id: openAnim
            target: pane
            fromScale: 0.98
        }

        MouseArea {
            anchors.fill: parent
            // Absorb clicks on empty glass so they do not close the popup.
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
