import QtQuick
import "../../services"
import "../../components"

// Shared by the live Dock and its Settings preview.
Item {
    id: root
    readonly property real cornerRadius: Math.min(Dock.cornerRadius, Math.min(width, height) / 2)

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        opacity: Dock.backgroundOpacity
        color: "transparent"

        SurfaceShadow {
            anchors.fill: parent
            z: -1
            cornerRadius: root.cornerRadius
            visible: !Dock.glassActive
            glowRadius: Dock.shadowGlowRadius
            spread: Dock.shadowSpread
        }
        LiquidGlassSurface {
            anchors.fill: parent
            z: -1
            active: Dock.glassActive
            cornerRadius: root.cornerRadius
            fallbackColor: Qt.alpha(Colors.surface, Colors.panelOpacity)
        }
    }
    SurfaceBorder {
        anchors.fill: parent
        visible: Dock.border
        radius: root.cornerRadius
        border.width: Dock.borderWidth
        tint: Dock.borderColor
        tintOpacity: Dock.borderOpacity
    }
}
