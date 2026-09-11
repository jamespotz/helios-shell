import QtQuick
import "../services"

// Procedural nebula background, ported from a WebGL2 shader
// (https://openshaders.com/@jamespotz). iTime free-runs via FrameAnimation
// so the flow keeps drifting; frozen under reduced motion. uLightMode
// blends the glow against Colors.background using the dark-mode (additive)
// or light-mode (subtractive) formula the source shader defines, so it
// still reads correctly if the theme flips while this is on screen.
ShaderEffect {
    id: root

    property real iTime: 0
    property size iResolution: Qt.size(width, height)
    property real uLightMode: Themes.isDark(Colors.background) ? 0.0 : 1.0
    property vector3d uBackground: Qt.vector3d(Colors.background.r, Colors.background.g, Colors.background.b)

    Behavior on uLightMode {
        NumberAnimation { duration: 400; easing.type: Easing.InOutQuad }
    }

    FrameAnimation {
        running: !Config.reducedMotion
        onTriggered: root.iTime += frameTime
    }

    // Nested Component construction (WlSessionLockSurface's `surface:
    // Component { ... }` in Lock.qml) resolves plain relative URLs against
    // the instantiating file, not this one — Qt.resolvedUrl pins it to
    // this file's own directory regardless of where it's instantiated from.
    vertexShader: Qt.resolvedUrl("shaders/flowfield.vert.qsb")
    fragmentShader: Qt.resolvedUrl("shaders/flowfield.frag.qsb")
}
