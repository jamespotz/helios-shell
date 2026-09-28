import QtQuick
import "../../../services"
import "../../../components"

// CPU load with two minutes of history bars, the system/user/idle split,
// and the hottest processes. `showGpuLine` is set by the Island when the
// GPU has no card of its own (the Battery card holds that slot).
MonitorCard {
    id: root

    readonly property var stats: SystemStats.state
    property bool showGpuLine: false

    function formatMemory(mb) {
        return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : mb.toFixed(1) + " MB";
    }

    value: root.stats.cpu.usage_percent.toFixed(0)
    unit: "%"
    label: "CPU Load"
    icon: "memory"
    actionText: "All Processes"

    BarGraph {
        width: parent.width
        height: 72
        values: root.stats.history.cpu
        warnAt: 60
        hotAt: 85
    }

    // Axis: the history is 60 samples, 2s apart.
    Item {
        width: parent.width
        height: axisRepeater.count > 0 ? axisRepeater.itemAt(0).implicitHeight : 0

        Repeater {
            id: axisRepeater
            model: ["2m", "90s", "60s", "30s", "now"]

            StyledText {
                required property int index
                required property string modelData
                x: index === 0 ? 0
                    : index === 4 ? parent.width - implicitWidth
                    : parent.width * index / 4 - implicitWidth / 2
                text: modelData
                opacity: 0.45
                font.pixelSize: Config.fontSize - 4
            }
        }
    }

    Item {
        width: parent.width
        height: splitText.implicitHeight

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showGpuLine && !!root.stats.gpu
            spacing: 5

            MaterialIcon { icon: "developer_board"; font.pixelSize: 13; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "GPU " + (root.stats.gpu ? root.stats.gpu.usage_percent.toFixed(0) : 0) + "%"
                font.pixelSize: Config.fontSize - 2
                font.weight: Font.Medium
            }
        }
        StyledText {
            id: splitText
            anchors.right: parent.right
            text: "System " + root.stats.cpu.times.system.toFixed(1) + "% · User "
                + root.stats.cpu.times.user.toFixed(1) + "% · Idle " + root.stats.cpu.times.idle.toFixed(1) + "%"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 3
            font.family: Config.monoFontFamily
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: root.stats.processes.length > 0

        Item {
            width: parent.width
            height: 22

            StyledText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Top Processes"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
            StyledText { x: parent.width - 150; width: 80; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: "Memory"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
            StyledText { anchors.right: parent.right; width: 60; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: "CPU"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
        }

        Repeater {
            model: root.stats.processes.slice(0, 5)

            Item {
                required property var modelData
                width: parent.width
                height: 26

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 160
                    elide: Text.ElideRight
                    text: modelData.name
                    font.pixelSize: Config.fontSize - 1
                }
                StyledText {
                    x: parent.width - 150
                    width: 80
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: root.formatMemory(modelData.memory_mb || 0)
                    opacity: 0.7
                    font.pixelSize: Config.fontSize - 2
                    font.family: Config.monoFontFamily
                }
                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: modelData.cpu_percent.toFixed(1) + "%"
                    color: root.levelColor(modelData.cpu_percent, 50, 80)
                    font.pixelSize: Config.fontSize - 2
                    font.family: Config.monoFontFamily
                }
            }
        }
    }
}
