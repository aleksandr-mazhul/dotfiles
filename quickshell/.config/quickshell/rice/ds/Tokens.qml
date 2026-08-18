pragma Singleton
import QtQuick
import ".."

// Design-system tokens — implementation of
// ~/projects/personal/desktop-design-system/tokens/tokens.md (Material v2, ADR-0005).
// Values: Draft until validated on screen. Palette comes from the color SSOT.
QtObject {
    // ————— Material v2: transparent satin glass —————
    // experiment/launcher-matte: airier plate, quieter grain, original edge language.
    // Tint stays above rice-popup ignore_alpha so Hyprland still frosts.
    readonly property color shellTint: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.14)
    // Glass levels go LIGHTER upwards (ADR-0005): raised / field are white-based lifts.
    readonly property color raised: Qt.rgba(1, 1, 1, 0.10)
    readonly property color raisedStrong: Qt.rgba(1, 1, 1, 0.14)
    readonly property color raisedRim: Qt.rgba(1, 1, 1, 0.08)
    readonly property color fieldFill: Qt.rgba(1, 1, 1, 0.07)
    readonly property color fieldRim: Qt.rgba(1, 1, 1, 0.14)
    // Edge of the plate — light, not a drawn frame.
    readonly property color rimOuter: Qt.rgba(1, 1, 1, 0.28)
    readonly property color rimLine: Qt.rgba(0, 0, 0, 0.10)
    readonly property color rimInner: Qt.rgba(1, 1, 1, 0.08)
    readonly property color sheen: Qt.rgba(1, 1, 1, 0.035)
    // Below ignore_alpha so the drop shadow is not frosted into a second pane.
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.07)
    readonly property color hairline: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.10)
    readonly property real noiseOpacity: 0.0

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
