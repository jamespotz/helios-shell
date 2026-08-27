import QtQuick
import "../../services"
import "../../components"

// Live system resource monitor — CPU/memory/GPU quick stats, per-core grid,
// memory + GPU meters, disk/network cumulative totals. Backed by
// services/SystemStats.qml, which spawns modules/bar/system-info.py (psutil
// + nvidia-smi) only while this tab is open.
Item {
    id: root

    readonly property var stats: SystemStats

    property bool live: true
    onLiveChanged: root.live ? SystemStats.start() : SystemStats.stop()

    Component.onCompleted: SystemStats.start()
    Component.onDestruction: SystemStats.stop()

    function levelColor(pct, warnAt, hotAt) {
        return pct >= hotAt ? Colors.danger : pct >= warnAt ? Colors.warning : Colors.accent;
    }

    implicitWidth: 620
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 16

        // --- Header: live indicator + pause toggle --------------------------
        Item {
            width: parent.width
            height: 28

            MaterialIcon { icon: "memory"; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.success
                    opacity: root.live ? 1 : 0.35

                    SequentialAnimation on opacity {
                        running: root.live
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.35; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.35; to: 1; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }
                StyledText {
                    text: root.stats.ready ? (root.live ? "Live" : "Paused") : "Waiting for data…"
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: root.live ? "pause" : "play_arrow"
                active: false
                onClicked: root.live = !root.live
            }
        }

        // --- Quick stats -----------------------------------------------------
        Row {
            width: parent.width
            spacing: 12

            Repeater {
                model: [
                    { label: "CPU", value: root.stats.cpu.usage_percent.toFixed(1) + "%",
                      sub: ((root.stats.cpu.frequency_mhz || 0) / 1000).toFixed(2) + " GHz",
                      color: root.levelColor(root.stats.cpu.usage_percent, 60, 85) },
                    { label: "Memory", value: root.stats.memory.usage_percent.toFixed(1) + "%",
                      sub: root.stats.memory.used_gb.toFixed(1) + " / " + root.stats.memory.total_gb.toFixed(1) + " GB",
                      color: root.levelColor(root.stats.memory.usage_percent, 75, 90) },
                    { label: "GPU", value: root.stats.gpu ? root.stats.gpu.usage_percent.toFixed(1) + "%" : "—",
                      sub: root.stats.gpu ? root.stats.gpu.name : "No GPU detected",
                      color: root.stats.gpu ? root.levelColor(root.stats.gpu.usage_percent, 75, 90) : Colors.subtext },
                    { label: "Active cores",
                      value: root.stats.cpu.per_core.filter(c => c > 0).length + " / " + root.stats.cpu.per_core.length,
                      sub: "above 0%", color: Colors.text }
                ]

                Rectangle {
                    id: statCard
                    required property var modelData
                    width: (col.width - 36) / 4
                    height: 66
                    radius: Colors.radiusLarge
                    color: Colors.surfaceHigh

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        width: parent.width - 24

                        StyledText { text: statCard.modelData.label; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                        StyledText {
                            text: statCard.modelData.value
                            color: statCard.modelData.color
                            font.bold: true
                            font.pixelSize: Config.fontSize + 6
                            font.family: Config.monoFontFamily
                        }
                        StyledText {
                            text: statCard.modelData.sub
                            opacity: 0.5
                            font.pixelSize: Config.fontSize - 4
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }
            }
        }

        // --- CPU cores ---------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Item {
                width: parent.width
                height: 18
                StyledText {
                    anchors.left: parent.left
                    text: "CPU · " + root.stats.cpu.per_core.length + " cores"
                    font.bold: true
                    font.pixelSize: Config.fontSize - 1
                }
                StyledText {
                    anchors.right: parent.right
                    text: root.stats.cpu.usage_percent.toFixed(1) + "% avg · " + ((root.stats.cpu.frequency_mhz || 0) / 1000).toFixed(2) + " GHz"
                    opacity: 0.5
                    font.pixelSize: Config.fontSize - 3
                    font.family: Config.monoFontFamily
                }
            }

            Grid {
                width: parent.width
                columns: 8
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: root.stats.cpu.per_core

                    Column {
                        id: coreCol
                        required property real modelData
                        required property int index
                        width: (col.width - 7 * 8) / 8
                        spacing: 5

                        Rectangle {
                            width: parent.width
                            height: 40
                            radius: Colors.radiusSmall
                            color: Colors.surfaceHigh

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: Math.max(3, parent.height * Math.min(coreCol.modelData, 100) / 100)
                                radius: Colors.radiusSmall
                                color: root.levelColor(coreCol.modelData, 70, 90)

                                Behavior on height { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                            }
                        }
                        StyledText {
                            text: coreCol.index
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.5
                            font.pixelSize: Config.fontSize - 5
                            font.family: Config.monoFontFamily
                        }
                    }
                }
            }
        }

        // --- Memory --------------------------------------------------------
        Column {
            width: parent.width
            spacing: 8

            Item {
                width: parent.width
                height: 18
                StyledText { anchors.left: parent.left; text: "Memory"; font.bold: true; font.pixelSize: Config.fontSize - 1 }
                StyledText {
                    anchors.right: parent.right
                    text: root.stats.memory.used_gb.toFixed(1) + " GB / " + root.stats.memory.total_gb.toFixed(1) + " GB"
                    opacity: 0.5
                    font.pixelSize: Config.fontSize - 3
                    font.family: Config.monoFontFamily
                }
            }

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Colors.surfaceHigh

                Rectangle {
                    width: parent.width * Math.min(root.stats.memory.usage_percent, 100) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.levelColor(root.stats.memory.usage_percent, 75, 90)
                    Behavior on width { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                }
            }

            Item {
                width: parent.width
                height: 14
                StyledText { anchors.left: parent.left; text: "Used · " + root.stats.memory.used_gb.toFixed(1) + " GB"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                StyledText {
                    anchors.right: parent.right
                    text: "Free · " + (root.stats.memory.total_gb - root.stats.memory.used_gb).toFixed(1) + " GB"
                    opacity: 0.5
                    font.pixelSize: Config.fontSize - 3
                }
            }
        }

        // --- GPU -------------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10
            visible: !!root.stats.gpu

            StyledText { text: "GPU"; font.bold: true; font.pixelSize: Config.fontSize - 1 }
            StyledText { text: root.stats.gpu ? root.stats.gpu.name : ""; opacity: 0.6; font.pixelSize: Config.fontSize - 2 }

            Column {
                width: parent.width
                spacing: 4

                Item {
                    width: parent.width
                    height: 14
                    StyledText { anchors.left: parent.left; text: "Utilization"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                    StyledText {
                        anchors.right: parent.right
                        text: root.stats.gpu ? root.stats.gpu.usage_percent.toFixed(1) + "%" : ""
                        opacity: 0.5
                        font.pixelSize: Config.fontSize - 3
                        font.family: Config.monoFontFamily
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Colors.surfaceHigh
                    Rectangle {
                        width: parent.width * (root.stats.gpu ? Math.min(root.stats.gpu.usage_percent, 100) / 100 : 0)
                        height: parent.height
                        radius: parent.radius
                        color: root.stats.gpu ? root.levelColor(root.stats.gpu.usage_percent, 75, 90) : Colors.accent
                        Behavior on width { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Column {
                id: vramCol
                width: parent.width
                spacing: 4

                readonly property real vramPct: root.stats.gpu ? (root.stats.gpu.memory_used_mb / root.stats.gpu.memory_total_mb) * 100 : 0

                Item {
                    width: parent.width
                    height: 14
                    StyledText { anchors.left: parent.left; text: "VRAM"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                    StyledText {
                        anchors.right: parent.right
                        text: root.stats.gpu ? (root.stats.gpu.memory_used_mb / 1024).toFixed(1) + " / " + (root.stats.gpu.memory_total_mb / 1024).toFixed(1) + " GB" : ""
                        opacity: 0.5
                        font.pixelSize: Config.fontSize - 3
                        font.family: Config.monoFontFamily
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Colors.surfaceHigh
                    Rectangle {
                        width: parent.width * Math.min(vramCol.vramPct, 100) / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.levelColor(vramCol.vramPct, 75, 90)
                        Behavior on width { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Item {
                width: parent.width
                height: 20
                StyledText { anchors.left: parent.left; text: "Temperature"; opacity: 0.6; font.pixelSize: Config.fontSize - 2 }
                StyledText {
                    anchors.right: parent.right
                    text: root.stats.gpu ? root.stats.gpu.temperature_c.toFixed(0) + "°C" : ""
                    font.bold: true
                    font.pixelSize: Config.fontSize
                    font.family: Config.monoFontFamily
                    color: !root.stats.gpu ? Colors.text
                        : root.stats.gpu.temperature_c >= 80 ? Colors.danger
                        : root.stats.gpu.temperature_c >= 65 ? Colors.warning : Colors.success
                }
            }
        }

        // --- Disk / network --------------------------------------------------
        Row {
            width: parent.width
            spacing: 24

            Column {
                width: (parent.width - 24) / 2
                spacing: 4

                StyledText { text: "Disk"; font.bold: true; font.pixelSize: Config.fontSize - 1 }

                Repeater {
                    model: [
                        { icon: "arrow_downward", name: "Read", value: (root.stats.disk.read_mb / 1024).toFixed(1) + " GB" },
                        { icon: "arrow_upward", name: "Write", value: (root.stats.disk.write_mb / 1024).toFixed(1) + " GB" }
                    ]

                    Item {
                        id: diskRow
                        required property var modelData
                        width: parent.width
                        height: 40

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                color: Colors.surfaceHigh
                                anchors.verticalCenter: parent.verticalCenter
                                MaterialIcon { anchors.centerIn: parent; icon: diskRow.modelData.icon; font.pixelSize: 13; opacity: 0.7 }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                StyledText { text: diskRow.modelData.name; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                                StyledText { text: diskRow.modelData.value; font.bold: true; font.family: Config.monoFontFamily }
                            }
                        }
                    }
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 4

                StyledText { text: "Network"; font.bold: true; font.pixelSize: Config.fontSize - 1 }

                Repeater {
                    model: [
                        { icon: "arrow_upward", name: "Sent", value: (root.stats.network.sent_mb / 1024).toFixed(1) + " GB" },
                        { icon: "arrow_downward", name: "Received", value: (root.stats.network.received_mb / 1024).toFixed(1) + " GB" }
                    ]

                    Item {
                        id: netRow
                        required property var modelData
                        width: parent.width
                        height: 40

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                color: Colors.surfaceHigh
                                anchors.verticalCenter: parent.verticalCenter
                                MaterialIcon { anchors.centerIn: parent; icon: netRow.modelData.icon; font.pixelSize: 13; opacity: 0.7 }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                StyledText { text: netRow.modelData.name; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                                StyledText { text: netRow.modelData.value; font.bold: true; font.family: Config.monoFontFamily }
                            }
                        }
                    }
                }
            }
        }
    }
}
