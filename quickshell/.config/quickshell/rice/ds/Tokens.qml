pragma Singleton
import QtQuick
import ".."

// Design-system tokens — implementation of
// ~/Projects/desktop-design-system/tokens/tokens.md (Material v2, ADR-0005).
// Values: Draft until validated on screen. Palette comes from the color SSOT.
QtObject {
    // ————— Material: glossy glass experiment (this branch) —————
    // Thinner dark tint so wallpaper colour reads through; light lives at the
    // top edge (specular) rather than as a milky full-surface veil.
    readonly property color shellTint: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.10)
    readonly property color shellLiftTop: Qt.rgba(1, 1, 1, 0.16)
    readonly property color shellLiftMid: Qt.rgba(1, 1, 1, 0.03)
    readonly property color shellLiftBottom: Qt.rgba(0, 0, 0, 0.08)
    readonly property color specular: Qt.rgba(1, 1, 1, 0.28)
    // Glass levels go LIGHTER upwards (ADR-0005): raised / field are white-based lifts.
    readonly property color raised: Qt.rgba(1, 1, 1, 0.11)
    readonly property color raisedStrong: Qt.rgba(1, 1, 1, 0.16)
    readonly property color raisedRim: Qt.rgba(1, 1, 1, 0.18)
    readonly property color fieldFill: Qt.rgba(1, 1, 1, 0.10)
    readonly property color fieldRim: Qt.rgba(1, 1, 1, 0.22)
    // Edge of the plate — light, not a drawn frame. Brighter outer rim = polish.
    readonly property color rimOuter: Qt.rgba(1, 1, 1, 0.46)
    readonly property color rimLine: Qt.rgba(0, 0, 0, 0.12)
    readonly property color rimInner: Qt.rgba(1, 1, 1, 0.14)
    readonly property color sheen: Qt.rgba(1, 1, 1, 0.10)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.30)
    readonly property color hairline: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
    readonly property real noiseOpacity: 0.008

    // ————— Shape (v2) —————
    readonly property int radiusSurface: 28
    readonly property int radiusMin: 8
    // Concentric nesting rule: inner = outer − padding (never below radiusMin)
    function innerRadius(outer, padding) {
        return Math.max(radiusMin, outer - padding)
    }

    // ————— Spacing (v2 — air) —————
    readonly property int paddingSurface: 14
    readonly property int rowHeight: 56
    readonly property int rowPaddingX: 16
    readonly property int gapInline: 12
    readonly property int gapSection: 20
    readonly property int sectionHeight: 38
    readonly property int searchFieldHeight: 52
    readonly property int footerHeight: 48
    readonly property int leadingSize: 28

    // ————— Text emphasis —————
    readonly property color textPrimary: Colors.text
    readonly property color textSecondary: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.65)
    readonly property color textTertiary: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.45)

    // ————— Type roles (UI = Adwaita Sans via SSOT; mono only for terminal contexts) —————
    readonly property string fontUi: Colors.font_ui
    readonly property int fontSize: 15
    readonly property int fontSizeSm: 12
    readonly property int fontSizeSection: 11
    readonly property real sectionTracking: 1.5

    // ————— Motion (interim values — Foundation/Motion is an Open Question) —————
    readonly property int stateMs: 120
    readonly property int openMs: 160
}
