import QtQuick
import "../services"

// Vertical counterpart to Slider.qml, used by MediaCard's equalizer bands.
Item {
    id: root

    property real value: 0.5 // 0..1
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
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * root.value
            radius: parent.radius
            color: root.fillColor
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
