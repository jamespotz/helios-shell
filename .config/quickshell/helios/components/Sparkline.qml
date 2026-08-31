import QtQuick
import "../services"

// Reusable bar-style sparkline — generalizes the Repeater-of-Rectangle
// idiom this shell already uses for ActivityTab.qml's weekly app-usage bars
// and MiniVisualizer.qml's audio levels, instead of introducing a new
// Canvas-based charting pattern with no precedent here.
//
// Requires an explicit `width` from the caller (e.g. `width: parent.width`)
// — bar width is derived from `root.width`, so an unset/implicit width
// would be circular. Same constraint ActivityTab's inline version has.
Row {
    id: root

    property var values: [] // numeric samples, oldest first
    property real barHeight: 32
    property real barSpacing: 2
    property color barColor: Colors.accent
    property int highlightIndex: -1
    property color highlightColor: Colors.accent

    readonly property real maxValue: Math.max(1, ...(root.values.length ? root.values : [0]))

    height: root.barHeight
    spacing: root.barSpacing

    Repeater {
        model: root.values

        Rectangle {
            required property real modelData
            required property int index

            width: root.values.length > 0
                ? (root.width - (root.values.length - 1) * root.barSpacing) / root.values.length : 0
            anchors.bottom: parent ? parent.bottom : undefined
            height: Math.max(2, root.barHeight * (modelData / root.maxValue))
            radius: 2
            color: index === root.highlightIndex ? root.highlightColor : root.barColor

            Behavior on height { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
        }
    }
}
