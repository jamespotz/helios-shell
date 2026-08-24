import QtQuick
import "../services"

Item {
    id: root

    property real value: 0 // 0..maxValue
    property real maxValue: 1
    // Draws a tick at this value (e.g. 1.0 to mark "100%" on a slider whose
    // maxValue goes past it) — set negative (default) to hide it.
    property real markerAt: -1
    property color fillColor: Colors.accent

    signal moved(real value)

    readonly property real fraction: root.maxValue > 0 ? Math.max(0, Math.min(1, root.value / root.maxValue)) : 0

    implicitHeight: 20

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Colors.surfaceHigh

        Rectangle {
            width: track.width * root.fraction
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }

        Rectangle {
            visible: root.markerAt >= 0 && root.markerAt <= root.maxValue
            width: 2
            height: parent.height + 6
            radius: 1
            color: Colors.background
            opacity: 0.6
            anchors.verticalCenter: parent.verticalCenter
            x: track.width * (root.maxValue > 0 ? root.markerAt / root.maxValue : 0) - width / 2
        }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: Colors.text
            anchors.verticalCenter: parent.verticalCenter
            x: track.width * root.fraction - width / 2
        }
    }

    MouseArea {
        anchors.fill: parent
        function posToValue(mx) {
            return Math.max(0, Math.min(1, mx / width)) * root.maxValue;
        }
        onPressed: mouse => root.moved(posToValue(mouse.x))
        onPositionChanged: mouse => { if (pressed) root.moved(posToValue(mouse.x)); }
    }
}
