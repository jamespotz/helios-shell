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
    readonly property bool showThumb: !root.thumbHoverOnly || trackHover.hovered || dragArea.pressed || root.activeFocus

    implicitHeight: 24
    opacity: root.enabled ? 1 : 0.4

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

            // Focus ring — keyboard-navigation feedback
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 2
                border.color: Colors.accent
                visible: root.activeFocus
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.enabled
        function posToValue(mx) {
            return Math.max(0, Math.min(1, mx / width)) * root.maxValue;
        }
        onPressed: mouse => { root.forceActiveFocus(); root.moved(posToValue(mouse.x)); }
        onPositionChanged: mouse => { if (pressed) root.moved(posToValue(mouse.x)); }
    }

    activeFocusOnTab: root.enabled
    readonly property real _step: root.maxValue > 0 ? root.maxValue / 20 : 0.05
    Keys.onLeftPressed: if (root.enabled) root.moved(Math.max(0, root.value - root._step))
    Keys.onRightPressed: if (root.enabled) root.moved(Math.min(root.maxValue, root.value + root._step))
}
