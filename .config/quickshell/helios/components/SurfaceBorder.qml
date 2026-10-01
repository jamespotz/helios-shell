import QtQuick
import "../services"

// Outline drawn over a floating surface (Dock, island, satellites). Sits
// outside the surface's background so background opacity doesn't fade it.
Rectangle {
    // "outline" or "accent".
    property string tint: "outline"
    property real tintOpacity: 0.5

    color: "transparent"
    border.color: Qt.alpha(tint === "accent" ? Colors.accent : Colors.outline, tintOpacity)
}
