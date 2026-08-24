import QtQuick
import "../../services"

// The island's background: a fully rounded floating pill, offset slightly
// from the true screen edge (see Bar.qml's margins.top) so the top corners'
// rounding is actually visible instead of being clipped flush against it.
Item {
    id: root

    property bool liquidGlassEnabled: false
    // Colors.surface everywhere except idle mode (Bar.qml passes
    // Colors.background there) — the compact pill blending toward black is
    // what sells the "floating in the notch" Dynamic Island illusion.
    property color fillColor: Colors.surface

    // height / 2 (not height * 0.34) so the small idle-bump/peek pills land
    // on a true stadium — a real Dynamic Island's compact shape — while
    // still capping at 22 for tall expanded panels, exactly as before.
    readonly property real cornerRadius: Math.max(4, Math.min(height / 2, 22))

    LiquidGlassSurface {
        anchors.fill: parent
        active: root.liquidGlassEnabled
        cornerRadius: root.cornerRadius
        fallbackColor: root.fillColor
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
