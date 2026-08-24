import QtQuick
import "../../services"

// The island's background: a fully rounded floating pill, offset slightly
// from the true screen edge (see Bar.qml's margins.top) so the top corners'
// rounding is actually visible instead of being clipped flush against it.
Item {
    id: root

    property bool liquidGlassEnabled: false

    readonly property real cornerRadius: Math.max(4, Math.min(height * 0.34, 22))
    readonly property color surfaceColor: Colors.surface

    LiquidGlassSurface {
        anchors.fill: parent
        active: root.liquidGlassEnabled
        cornerRadius: root.cornerRadius
        fallbackColor: Colors.surface
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: Colors.overlay
        opacity: 0.6
    }
}
