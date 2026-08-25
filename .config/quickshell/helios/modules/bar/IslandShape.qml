import QtQuick
import "../../services"

// The island's background — Apple-style vibrancy material: a translucent
// surface with subtle gradient depth, soft inner shadow, and a fine
// separator border. The pill floats off the screen edge (Bar.qml's
// margins.top) so all four corners' continuous rounding is visible.
Item {
    id: root

    property bool liquidGlassEnabled: false
    // Colors.surface everywhere except idle mode (Bar.qml passes
    // Colors.background there) — the compact pill blending toward pure
    // black sells the "floating notch" illusion.
    property color fillColor: Colors.surface

    // Apple's continuous corner (squircle) can't be done in pure QML
    // without ShaderEffect, but a generous radius relative to height
    // gets close. Stadium for small pills, capped for tall panels.
    readonly property real cornerRadius: Math.max(6, Math.min(height / 2, 18))

    LiquidGlassSurface {
        anchors.fill: parent
        active: root.liquidGlassEnabled
        cornerRadius: root.cornerRadius
        fallbackColor: root.fillColor
    }

    // Subtle inner highlight along the top edge — mimics the way Apple's
    // dark-mode materials catch a hair of light at the top. Kept a literal
    // white (like LiquidGlassSurface's own rim) since it's a physical
    // light-catch effect, not themed UI chrome.
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.width: 0.5
        border.color: Qt.rgba(1, 1, 1, 0.12)
    }

    // Fine separator — slightly more visible than the inner highlight,
    // defines the shape against any wallpaper.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -0.5
        radius: root.cornerRadius + 0.5
        color: "transparent"
        border.width: 0.5
        border.color: Qt.rgba(Colors.shadow.r, Colors.shadow.g, Colors.shadow.b, 0.4)
    }
}
