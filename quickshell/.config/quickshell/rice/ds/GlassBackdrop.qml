import QtQuick
import Quickshell.Wayland

// The pixels a glass sheet refracts.
//
// A Wayland client cannot read the compositor's framebuffer, so the sheet gets
// its own: one screencopy frame of the output, plus a frosted copy of it. That
// is what makes the refraction real rather than a painted gradient.
//
// Must be a child of the window that hosts the glass — an item outside a mapped
// window never renders, and an unrendered item has no texture to sample.
//
// The frame is frozen on purpose. Capturing live would photograph the sheet
// itself and feed it back into its own refraction, one generation darker each
// frame. Popups are modal and short-lived, so a still backdrop is unnoticeable;
// re-arm() on anything that changes what is behind (open, workspace switch).
Item {
    id: root

    // Fill the window: uv mapping in the shader assumes source == window.
    anchors.fill: parent
    opacity: 0
    // Not visible:false — an invisible item is not rendered, and then there is
    // nothing for ShaderEffectSource to read.

    property var captureSource: null
    // True for as long as the host popup is open.
    property bool active: false
    // True only for the few frames where the mip chain is allowed to update.
    property bool settling: false
    readonly property bool ready: cap.hasContent && !settling
    // False when the compositor refuses screencopy: hosts fall back rather than
    // painting a black slab out of empty textures.
    readonly property bool hasContent: cap.hasContent

    readonly property Item sharp: sharpSrc
    readonly property Item blur: mip4

    // One texel of the frost texture, for the shader's tent.
    readonly property int frostScale: 16
    readonly property real blurTexelX: frostScale / Math.max(1, width)
    readonly property real blurTexelY: frostScale / Math.max(1, height)

    signal captured()

    // Grab a fresh frame, then freeze. Call with the sheet still hidden.
    function arm() {
        settling = true
        settleTimer.restart()
    }

    Timer {
        id: settleTimer
        // ~6 frames at 60Hz: screencopy has to land AND the four mip levels have
        // to run through before anything freezes.
        interval: 96
        onTriggered: {
            root.settling = false
            root.captured()
        }
    }

    // The capture keeps running for as long as the popup is open — it is NOT
    // tied to `settling`.
    //
    // Tying both to the same flag meant the ScreencopyView and the mip chain
    // stopped on the same frame, and if the view blanked first the chain froze
    // that blank. A black capture makes the shader render a flat slab with no
    // backdrop in it at all, which looks like a taste problem and is not one.
    // Freezing only the mips is also what keeps the sheet out of its own
    // refraction: nothing samples this view once the chain has stopped.
    ScreencopyView {
        id: cap
        anchors.fill: parent
        captureSource: root.captureSource
        live: root.active
        paintCursor: false
    }

    ShaderEffectSource {
        id: sharpSrc
        anchors.fill: parent
        sourceItem: cap
        live: root.settling
        recursive: false
    }

    // Frost = a mip pyramid, halved one step at a time.
    //
    // Rendering straight to 1/16 does NOT average: ShaderEffectSource does one
    // scaled draw, so a 16x reduction point-samples and aliases, and the result
    // is crunchy blobs rather than frost. Each HALVING with linear filtering is
    // an exact 2x2 box, so four of them reach 1/16 cleanly.
    component Halve: ShaderEffectSource {
        required property Item from
        required property int step
        anchors.fill: parent
        sourceItem: from
        textureSize: Qt.size(Math.max(1, Math.round(root.width / step)),
                             Math.max(1, Math.round(root.height / step)))
        smooth: true
        live: root.settling
        recursive: false
    }

    Halve { id: mip1; from: sharpSrc; step: 2 }
    Halve { id: mip2; from: mip1; step: 4 }
    Halve { id: mip3; from: mip2; step: 8 }
    Halve { id: mip4; from: mip3; step: root.frostScale }
}
