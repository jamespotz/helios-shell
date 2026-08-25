import QtQuick
import "../services"

// A tiny equalizer driven by live cava bar levels (0..1 each).
Row {
    id: root

    property bool active: false
    property color barColor: Colors.text
    property var levels: []
    property int maxHeight: 10

    spacing: 2

    Repeater {
        model: root.levels.length

        Rectangle {
            width: 2
            radius: 1
            color: root.barColor
            anchors.bottom: parent ? parent.bottom : undefined
            height: Math.max(2, root.maxHeight * (root.active ? root.levels[index] : 0))

            Behavior on height {
                NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
            }
        }
    }
}
