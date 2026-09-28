import QtQuick
import "../services"

// Rolling history bars for live samples: one bar per slot on a faint track,
// each colored by its own level. Samples are right-aligned on a fixed
// `capacity` grid, so a graph that is still warming up fills in from the
// right. The Repeater models a count, not `values`, so delegates stay put
// and only their heights change on each tick.
//
// Requires an explicit `width` and `height` from the caller.
Item {
    id: root

    property var values: [] // numeric samples, oldest first
    property int capacity: 60
    property real maxValue: 100
    property real warnAt: 60
    property real hotAt: 85
    property real spacing: 2

    readonly property int barCount: bars.count

    // Sample shown in slot `index`, or -1 while that slot has no sample yet.
    function valueAt(index) {
        const i = root.values.length - root.capacity + index;
        return i >= 0 ? root.values[i] : -1;
    }

    function colorFor(value) {
        return value >= root.hotAt ? Colors.danger : value >= root.warnAt ? Colors.warning : Colors.accent;
    }

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            id: bars
            model: root.capacity

            Rectangle {
                id: bar
                required property int index
                readonly property real value: root.valueAt(bar.index)

                width: (root.width - (root.capacity - 1) * root.spacing) / root.capacity
                height: root.height
                radius: Math.min(2, width / 2)
                color: Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.25)

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: bar.value >= 0
                    height: Math.max(2, parent.height * Math.min(Math.max(bar.value, 0), root.maxValue) / root.maxValue)
                    radius: parent.radius
                    color: root.colorFor(bar.value)

                    Behavior on height {
                        enabled: !Config.reducedMotion
                        NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
