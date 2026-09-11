
import QtQuick
import QtQuick.Effects
import "../services"

// Shared shadow for floating shell surfaces. Layer-shell compositors do not
// provide window-decoration shadows, so this stays inside Helios' surfaces.
Item {
    id: root

    // Expose properties to allow parents to pass their target content element
    property Item targetSource: null 

    property real cornerRadius: Colors.radiusLarge
    property real glowRadius: 14   // Maps directly to 'blur' in RectangularShadow
    property real spread: 0.08     // Handled as a percentage or raw pixels
    property real verticalOffset: 4
    property real shadowOpacity: 0.32

    // Modern Qt6 Hardware-Accelerated Shadow for Quickshell
    RectangularShadow {
        id: shadowEffect
        
        // Match the bounding area of the target surface component
        anchors.fill: root.targetSource ? root.targetSource : parent
        
        // Geometry mapping
        offset.x: 0
        offset.y: root.verticalOffset
        blur: root.glowRadius
        spread: root.spread * 100 // RectangularShadow treats spread on a 0-100 scale
        radius: root.cornerRadius
        opacity: root.shadowOpacity
        
        // Color mapping from your service
        color: Qt.rgba(Colors.shadow.r, Colors.shadow.g, Colors.shadow.b, 1.0)
    }
}

