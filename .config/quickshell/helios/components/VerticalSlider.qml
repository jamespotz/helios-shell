import QtQuick
import "../services"

// Vertical counterpart to Slider.qml, used by MediaCard's equalizer bands.
// Fill is bidirectional from centerValue (0dB) rather than bottom-up, so a
// band reads as "boosted" or "cut" the way a real EQ does.
Item {
    id: root

    property real value: 0.5 // 0..1
    property real centerValue: 0.5
    property color fillColor: Colors.accent

    signal moved(real value)
    signal released()

    implicitWidth: 18
    width: implicitWidth

    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        radius: 2
        color: Colors.surfaceHigh

        Rectangle {
            // 0dB tie line
            anchors.horizontalCenter: parent.horizontalCenter
            width: 10
            height: 1
            color: Colors.overlay
            opacity: 0.6
            y: track.height * (1 - root.centerValue) - height / 2
        }

        Rectangle {
            readonly property real topFrac: 1 - Math.max(root.value, root.centerValue)
            readonly property real bottomFrac: 1 - Math.min(root.value, root.centerValue)

            width: parent.width
            radius: parent.radius
            color: root.fillColor
            y: track.height * topFrac
            height: Math.max(0, track.height * (bottomFrac - topFrac))
        }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: Colors.text
            anchors.horizontalCenter: parent.horizontalCenter
            y: track.height * (1 - root.value) - height / 2
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        // The tab content sits in a vertically-scrolling Flickable
        // (PanelWrapper.qml) — without this, a vertical drag here gets
        // stolen by the Flickable's own scroll gesture instead of moving
        // the slider.
        preventStealing: true
        function posToValue(my) {
            return Math.max(0, Math.min(1, 1 - my / root.height));
        }
        onPressed: mouse => root.moved(posToValue(mouse.y))
        onPositionChanged: mouse => { if (pressed) root.moved(posToValue(mouse.y)); }
        onReleased: root.released()
    }
}
