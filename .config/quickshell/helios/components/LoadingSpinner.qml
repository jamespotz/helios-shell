import QtQuick
import "../services"

// Small rotating indicator for async operations (wifi/bluetooth scans, etc).
// Material's "progress_activity" glyph is a partial ring, so spinning it
// reads as a loading spinner without a custom Canvas/shader.
MaterialIcon {
    id: root

    property bool active: false

    icon: "progress_activity"
    color: Colors.accent

    RotationAnimation on rotation {
        running: root.active && !Config.reducedMotion
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}
