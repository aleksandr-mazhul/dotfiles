pragma Singleton
import QtQuick
import ".."

// Neutral optical glass. Color comes from frost, never from a tint.
// shellTint alpha stays above rice-popup ignore_alpha so Hyprland still frosts.
// Contrast: scene luma → glyph halo + well scrims. Plate stays empty (ADR-0007).
QtObject {
    id: tok

    readonly property real contrast: AdaptiveContrast.contrast

    readonly property color shellTint: Qt.rgba(1, 1, 1, 0.038)
    readonly property color raised: Qt.rgba(1, 1, 1, 0.04 * (1 - tok.contrast * 0.70))
    readonly property color raisedStrong: Qt.rgba(1, 1, 1, 0.06 * (1 - tok.contrast * 0.82))
    readonly property color raisedRim: Qt.rgba(1, 1, 1, 0.30 + tok.contrast * 0.08)
    readonly property color fieldFill: Qt.rgba(1, 1, 1, 0.055 * (1 - tok.contrast * 0.78))
    readonly property color fieldRim: Qt.rgba(1, 1, 1, 0.22 + (1 - tok.contrast) * 0.08)
    readonly property color focusGlow: Qt.rgba(1, 1, 1, 0.025)
    readonly property color focusRim: Qt.rgba(1, 1, 1, 0.36)
    readonly property color selectGlow: Qt.rgba(1, 1, 1, 0.025)
    readonly property color rimOuter: Qt.rgba(1, 1, 1, 0.34 + (1 - tok.contrast) * 0.10)
    readonly property color rimInner: Qt.rgba(0, 0, 0, 0.04 + tok.contrast * 0.28)
    readonly property color sheen: Qt.rgba(1, 1, 1, 0.04)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.025)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.14)
    readonly property real noiseOpacity: 0.0

    // Neutral black only. Bright frost needs real ink or white type vanishes.
    // Plate stays empty (ADR-0007). Ink lives in wells + glyph halo.
    readonly property color paneScrim: Qt.rgba(0, 0, 0, 0)
    readonly property color searchScrim: Qt.rgba(0, 0, 0, 0.06 + tok.contrast * 0.18)
    readonly property color listScrim: Qt.rgba(0, 0, 0, 0.06 + tok.contrast * 0.22)
    readonly property color footerScrim: Qt.rgba(0, 0, 0, 0.05 + tok.contrast * 0.16)
    readonly property color selectScrim: Qt.rgba(0, 0, 0, 0.06 + tok.contrast * 0.16)
    readonly property color fieldScrim: Qt.rgba(0, 0, 0, 0.05 + tok.contrast * 0.18)

    readonly property int radiusSurface: 30
    readonly property int radiusMin: 8
    readonly property int radiusField: 18
    function innerRadius(outer, padding) {
        return Math.max(radiusMin, outer - padding)
    }

    readonly property int paddingSurface: 16
    readonly property int rowHeight: 52
    readonly property int rowPaddingX: 16
    readonly property int paddingFieldX: 16
    readonly property int gapInline: 12
    readonly property int gapSection: 18
    readonly property int sectionHeight: 32
    readonly property int searchFieldHeight: 52
    readonly property int footerHeight: 44
    readonly property int leadingSize: 26

    readonly property color textPrimary: Qt.rgba(1, 1, 1, 0.94)
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.62 + tok.contrast * 0.12)
    readonly property color textTertiary: Qt.rgba(1, 1, 1, 0.54 + tok.contrast * 0.14)
    readonly property color textIcon: Qt.rgba(1, 1, 1, 0.90 + tok.contrast * 0.06)
    readonly property color textHalo: Qt.rgba(0, 0, 0, 0.30 + tok.contrast * 0.22)
    readonly property color textShadow: Qt.rgba(0, 0, 0, 0.28 + tok.contrast * 0.24)
    readonly property color iconHalo: Qt.rgba(0, 0, 0, 0.28 + tok.contrast * 0.24)

    readonly property string fontUi: Colors.font_ui
    readonly property int fontSize: 15
    readonly property int fontSizeSm: 12
    readonly property int fontSizeSection: 11
    readonly property real sectionTracking: 1.6

    readonly property int stateMs: 120
    readonly property int openMs: 160
}
