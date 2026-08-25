import QtQuick
import "../services"

// Apple vibrancy-style panel background — more translucent than before
// to let blur show through, with a subtle 0.5px border for definition.
Rectangle {
    color: Colors.surface
    opacity: Colors.panelOpacity
    radius: Colors.radiusLarge
    border.width: 0.5
    border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)
}
