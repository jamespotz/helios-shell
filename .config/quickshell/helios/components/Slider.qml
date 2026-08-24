import QtQuick
import "../services"

// Apple-style slider — taller track (8px) with generous rounded ends,
// accent fill, and a hover-only thumb (Apple Music scrubber behavior).
// The thumb is slightly larger (16px) with a white fill for visibility.
Item {
    id: root

    property real value: 0
    property real maxValue: 1
    property real markerAt: -1
    property color fillColor: Colors.accent
    property real trackHeight: 8
    property bool thumbHoverOnly: false

    signal moved(real value)

    readonly property real fraction: root.maxValue > 0 ? Math.max(0, Math.min(1, root.value / root.maxValue)) : 0
    readonly property bool showThumb: !root.thumbHoverOnly || trackHover.hovered || dragArea.pressed

    implicitHeight: 24

    HoverHandler { id: trackHover }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: Colors.surfaceHigh

        // Fill
        Rectangle {
            width: track.width * root.fraction
            height: parent.height
            radius: parent.radius
            color: root.fillColor
        }

        // Tick marker
        Rectangle {
            visible: root.markerAt >= 0 && root.markerAt <= root.maxValue
            width: 2
            height: parent.height + 4
            radius: 1
            color: Colors.background
            opacity: 0.5
            anchors.verticalCenter: parent.verticalCenter
            x: track.width * (root.maxValue > 0 ? root.markerAt / root.maxValue : 0) - width / 2
        }

        // Thumb — white circle, appears on hover/drag
        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: "#ffffff"
            opacity: root.showThumb ? 1 : 0
            anchors.verticalCenter: parent.verticalCenter
            x: track.width * root.fraction - width / 2

            Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

            // Shadow ring
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: parent.radius + 1
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.15)
                z: -1
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        function posToValue(mx) {
            return Math.max(0, Math.min(1, mx / width)) * root.maxValue;
        }
        onPressed: mouse => root.moved(posToValue(mouse.x))
        onPositionChanged: mouse => { if (pressed) root.moved(posToValue(mouse.x)); }
    }
}
