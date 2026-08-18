import QtQuick

// Soft lens-edge for material.shell: one SDF band (highlight → refraction →
// fade), not stacked 1px frames. Sits inside the plate so Hyprland frost
// does not speckle the rounded corner.
ShaderEffect {
    property real radius: Tokens.radiusSurface
    property real itemWidth: width
    property real itemHeight: height
    property real contrast: AdaptiveContrast.contrast

    fragmentShader: Qt.resolvedUrl("glassedge.frag.qsb")
    vertexShader: Qt.resolvedUrl("glassedge.vert.qsb")
    blending: true
    supportsAtlasTextures: false
}
