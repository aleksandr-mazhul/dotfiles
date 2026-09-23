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
            // PanelWindow is not an Item: focus the pane (it owns the Esc handler).
            pane.forceActiveFocus()
            if (typeof root.refocusHandler === "function")
                root.refocusHandler()
        })
    }

    // grim -g string for the pixels the plate will cover (or a strip above it).
    function sceneGeom(outsideBand) {
        const w = Math.round(pane.width)
        let h = Math.round(pane.height)
        if (w < 32)
            return ""
        if (h < 32)
            h = 420
        const lx = Math.round((root.width - w) / 2)
        const ly = Math.round(root.height * root.anchorY)
        // The surface is anchored to all edges with ExclusionMode.Ignore, so
        // window-local coords map to global by the screen's layout origin.
        const scr = root.screen
        let gx = lx + Math.round(scr ? scr.x : 0)
        let gy = ly + Math.round(scr ? scr.y : 0)
        if (gx < 0)
            gx = 0
        if (gy < 0)
            gy = 0
        if (outsideBand) {
            const band = 28
            const by = Math.max(0, gy - band)
            return gx + "," + by + " " + w + "x" + band
        }
        return gx + "," + gy + " " + w + "x" + h
    }

    function refreshScene(outsideBand) {
        AdaptiveContrast.refresh(root.sceneGeom(!!outsideBand))
    }

    function toggle() {
        if (open)
            close()
        else
            show()
    }

    function present() {
        root.refreshScene(false)
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
        root.refreshScene(false)
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
            root.refreshScene(true)
            Qt.callLater(() => {
                if (!root.open)
                    return
                focusGrab.active = true
                root.grabFocus()
            })
        }
    }

    // FocusScope so forceActiveFocus() lands on the content's focused child
    // (e.g. a search field) instead of stealing focus from it.
    FocusScope {
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
