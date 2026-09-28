import QtQuick
import "../../../services"
import "../../../components"

MonitorCard {
    id: root

    readonly property var stats: SystemStats.state
    readonly property var memory: root.stats.memory

    title: "Memory"
    icon: "memory_alt"

    // Pressure bar: one segment per 10% in use.
    Row {
        width: parent.width
        spacing: 4

        Repeater {
            model: 10

            Rectangle {
                required property int index
                width: (root.width - root.padding * 2 - 9 * 4) / 10
                height: 6
                radius: 3
                color: root.memory.usage_percent >= (index + 1) * 10
                    ? root.levelColor(root.memory.usage_percent, 75, 90) : Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.25)

                Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
            }
        }
    }

    LineGraph {
        width: parent.width
        height: 40
        values: root.stats.history.memory
        maxValue: 100
        lineColor: root.levelColor(root.memory.usage_percent, 75, 90)
    }

    StatRow { width: parent.width; label: "Physical Memory"; value: root.memory.total_gb.toFixed(1) + " GB" }
    StatRow { width: parent.width; label: "Memory Used"; value: root.memory.used_gb.toFixed(1) + " GB" }
    StatRow { width: parent.width; label: "Cached Files"; value: root.memory.cached_gb.toFixed(1) + " GB" }
    StatRow { width: parent.width; label: "Swap Used"; value: root.memory.swap_used_gb.toFixed(1) + " GB" }
}
