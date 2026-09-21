pragma Singleton
import QtQuick
import ".."

// The grade: scene luminance in, glass optics and ink polarity out.
//
// One look: smoked glass that absorbs a fixed fraction of whatever is behind it
// (see liquidglass.frag). Because it always darkens rather than replacing the
// backdrop with a fill, white type holds over a white page and the backdrop's
// structure still shows through. No per-element scrims, no polarity flip.
QtObject {
    id: grade

    // 0 = dark scene, 1 = blown out. Measured by AdaptiveContrast (grim + luma).
    readonly property real luma: AdaptiveContrast.contrast

    // ONE look, pinned dark. There is no light/dark flip any more.
    //
    // Flipping polarity by wallpaper brightness meant two consecutive opens over
    // the same screen could show two different skins — one dark, one grey — which
    // reads as the shell being broken, not as it adapting. The absorption model
    // below removes the need for it: the sheet always darkens what is behind it,
    // so white type holds over a white page just as well as over a black one.
    readonly property real light: 0

    function latch() {}

    function lerp(dark, lightVal) { return dark }

    // ---- body ---------------------------------------------------------------
    // absorb = how much of the backdrop passes through. This is the transparency
    // dial: 0.34 means a white page behind reads as mid grey and a dark desktop
    // reads as near black, while in BOTH cases the backdrop's own shapes are
    // still visible through the sheet, just scaled down.
    readonly property real absorb: 0.34
    // The sheet's own scatter. Without it the glass is darker than the desktop
    // and reads as a hole punched in the screen rather than as a pane.
    readonly property real veil: 0.055
    readonly property real satur: 1.18
    // Light gathers at the top of the pane and falls away below.
    readonly property real bodyTilt: 0.18

    // ---- optics -------------------------------------------------------------
    readonly property real bevel: 38
    readonly property real lens: 54
    readonly property real disperse: 0.055
    readonly property real cornerPower: 4.0
    readonly property real pad: 78

    // ~3px of catch-light, not ~1px: one pixel at this alpha disappears at
    // native resolution, which is how the edge ended up reading as nothing.
    readonly property real lipWidth: 3.2

    readonly property real specA: 0.66
    readonly property real lipDarkA: 0.0
    readonly property real causticA: 0.12
    readonly property real innerA: 0.22
    // Wide and soft. A tight, strong shadow hugs the outline and reads as a
    // drawn frame around the popup instead of as the sheet floating.
    readonly property real shadowA: 0.30
    readonly property real shadowSize: 72

    // ---- ink ----------------------------------------------------------------
    function ink(darkA, lightA) {
        return grade.light > 0.5
            ? Qt.rgba(0.04, 0.04, 0.05, lightA)
            : Qt.rgba(1, 1, 1, darkA)
    }

    readonly property color textPrimary: ink(0.95, 0.92)
    readonly property color textSecondary: ink(0.66, 0.66)
    readonly property color textTertiary: ink(0.52, 0.55)
    readonly property color textIcon: ink(0.90, 0.82)

    // Icons carry the same rule as type: the halo only helps light glyphs.
    readonly property color textHalo: Qt.rgba(0, 0, 0, 0.26 * (1 - grade.light))

    // ---- glass on glass -----------------------------------------------------
    // A field or a pill is a second, thinner sheet — a film of light plus one
    // hairline. Never a filled box with a visible border: stacking opaque
    // rectangles on the plate is what made the old launcher read as chrome.
    readonly property color film: Qt.rgba(1, 1, 1, lerp(0.055, 0.34))
    readonly property color filmStrong: Qt.rgba(1, 1, 1, lerp(0.085, 0.52))
    readonly property color hairline: grade.light > 0.5
        ? Qt.rgba(0, 0, 0, 0.10)
        : Qt.rgba(1, 1, 1, 0.13)
    // The lit top edge of an inset sheet, and the shaded bottom edge under it.
    readonly property color edgeLit: Qt.rgba(1, 1, 1, lerp(0.20, 0.62))
    readonly property color edgeShade: Qt.rgba(0, 0, 0, lerp(0.16, 0.09))
    readonly property color focusRim: grade.light > 0.5
        ? Qt.rgba(0, 0, 0, 0.26)
        : Qt.rgba(1, 1, 1, 0.34)
}
