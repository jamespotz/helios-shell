import QtQuick
import "../../../services"
import "../../../components"

MonitorCard {
    id: root

    readonly property var gpu: SystemStats.state.gpu
    readonly property real vramPercent: root.gpu && root.gpu.memory_total_mb > 0
        ? root.gpu.memory_used_mb / root.gpu.memory_total_mb * 100 : 0

    value: root.gpu ? root.gpu.usage_percent.toFixed(0) : "—"
    unit: root.gpu ? "%" : ""
    label: "GPU Load"
    icon: "developer_board"
    footerText: root.gpu ? root.gpu.name : ""

    Meter {
        width: parent.width
        percent: root.vramPercent
        fillColor: root.levelColor(root.vramPercent, 75, 90)
    }
    StatRow {
        width: parent.width
        label: "VRAM"
        value: root.gpu ? (root.gpu.memory_used_mb / 1024).toFixed(1) + " / " + (root.gpu.memory_total_mb / 1024).toFixed(1) + " GB" : "—"
    }
}
