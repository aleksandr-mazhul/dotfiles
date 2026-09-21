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
    // The sheet stays hidden until its backdrop frame has landed.
    property bool revealed: false
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
        let gx = lx
        let gy = ly
        if (typeof root.mapToGlobal === "function") {
            const p = root.mapToGlobal(Qt.point(lx, ly))
            if (p) {
                gx = Math.round(p.x)
                gy = Math.round(p.y)
            }
        }
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
        revealed = false
        open = true
        // Grab the backdrop while the sheet is still hidden: a live capture
        // would photograph the glass and refract it into itself.
        // Decide the ink polarity while nothing is on screen yet.
        GlassGrade.latch()
        backdrop.arm()
        popupOpened()
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
        revealed = false
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
        revealed = false
        pane.opacity = 1
        pane.scale = 1
    }

    function resume() {
        parked = false
        root.refreshScene(false)
        revealed = false
        open = true
        // Decide the ink polarity while nothing is on screen yet.
        GlassGrade.latch()
        backdrop.arm()
        resumed()
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
            // A different workspace is different pixels, and the sheet is
            // refracting a frozen frame of the old one. Hide it while the new
            // frame is grabbed, or the capture photographs the sheet itself.
            root.revealed = false
            backdrop.arm()
            Qt.callLater(() => {
                if (!root.open)
                    return
                focusGrab.active = true
                root.grabFocus()
            })
        }
    }

    GlassBackdrop {
        id: backdrop
        captureSource: root.screen
        active: root.open
        onCaptured: {
            if (!root.open)
                return
            root.revealed = true
            openAnim.play()
        }
    }

    Item {
        id: pane
        visible: root.revealed
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

        LiquidGlass {
            id: glass
            anchors.fill: parent
            // The shader draws its own contact shadow in a padding ring, so the
            // item overflows the pane on every side.
            anchors.margins: -glass.pad
            backdrop: backdrop
            // pane is horizontalCenter-anchored and y-bound, so both notify.
            originX: pane.x - glass.pad
            originY: pane.y - glass.pad
            radius: Tokens.radiusSurface

            Item {
                id: inner
                anchors.fill: parent
            }
        }
    }
}
