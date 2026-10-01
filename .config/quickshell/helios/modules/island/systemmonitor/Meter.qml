import QtQuick
import "../../../services"

// Thin horizontal level meter used across System monitor cards.
Rectangle {
    id: root

    property real percent: 0
    property color fillColor: Colors.accent

    implicitHeight: 6
    radius: height / 2
    color: Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.25)

    Rectangle {
        width: parent.width * Math.max(0, Math.min(root.percent, 100)) / 100
        height: parent.height
        radius: parent.radius
        color: root.fillColor

        Behavior on width {
            enabled: !Config.reducedMotion
            NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic }
        }
        Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
    }
}
