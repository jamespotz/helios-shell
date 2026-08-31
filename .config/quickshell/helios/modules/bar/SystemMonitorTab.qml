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
        // Four fixed cards, not data-driven, so these are written out
        // directly rather than fed through a Repeater over an array literal
        // — that array was rebuilt (destroying/recreating all 4 delegates)
        // on every ~5s stats tick for no benefit, since the count and
        // identity of these cards never actually varies.
        Row {
            width: parent.width
            spacing: 12

            Rectangle {
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

                    StyledText { text: "CPU"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                    StyledText {
                        text: root.stats.cpu.usage_percent.toFixed(1) + "%"
                        color: root.levelColor(root.stats.cpu.usage_percent, 60, 85)
                        font.bold: true
                        font.pixelSize: Config.fontSize + 6
                        font.family: Config.monoFontFamily
                    }
                    StyledText {
                        text: ((root.stats.cpu.frequency_mhz || 0) / 1000).toFixed(2) + " GHz"
                        opacity: 0.5
                        font.pixelSize: Config.fontSize - 4
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            Rectangle {
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

                    StyledText { text: "Memory"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                    StyledText {
                        text: root.stats.memory.usage_percent.toFixed(1) + "%"
                        color: root.levelColor(root.stats.memory.usage_percent, 75, 90)
                        font.bold: true
                        font.pixelSize: Config.fontSize + 6
                        font.family: Config.monoFontFamily
                    }
                    StyledText {
                        text: root.stats.memory.used_gb.toFixed(1) + " / " + root.stats.memory.total_gb.toFixed(1) + " GB"
                        opacity: 0.5
                        font.pixelSize: Config.fontSize - 4
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            Rectangle {
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

                    StyledText { text: "GPU"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                    StyledText {
                        text: root.stats.gpu ? root.stats.gpu.usage_percent.toFixed(1) + "%" : "—"
                        color: root.stats.gpu ? root.levelColor(root.stats.gpu.usage_percent, 75, 90) : Colors.subtext
                        font.bold: true
                        font.pixelSize: Config.fontSize + 6
                        font.family: Config.monoFontFamily
                    }
                    StyledText {
                        text: root.stats.gpu ? root.stats.gpu.name : "No GPU detected"
                        opacity: 0.5
                        font.pixelSize: Config.fontSize - 4
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            Rectangle {
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

                    StyledText { text: "Active cores"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                    StyledText {
                        text: root.stats.cpu.per_core.filter(c => c > 0).length + " / " + root.stats.cpu.per_core.length
                        color: Colors.text
                        font.bold: true
                        font.pixelSize: Config.fontSize + 6
                        font.family: Config.monoFontFamily
                    }
                    StyledText {
                        text: "above 0%"
                        opacity: 0.5
                        font.pixelSize: Config.fontSize - 4
                        elide: Text.ElideRight
                        width: parent.width
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
                    // A count, not the array itself — per_core is reassigned
                    // wholesale on every ~5s tick, so modeling on the array
                    // directly would destroy/recreate all 16+ delegates every
                    // tick and the Behaviors below would never get a chance
                    // to animate (a freshly-created item just snaps to its
                    // initial value). Core *count* is effectively static for
                    // a running system, so this keeps delegate identity
                    // stable and lets `pct` update in place instead.
                    model: root.stats.cpu.per_core.length

                    Column {
                        id: coreCol
                        required property int index
                        readonly property real pct: root.stats.cpu.per_core[coreCol.index] || 0
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
                                height: Math.max(3, parent.height * Math.min(coreCol.pct, 100) / 100)
                                radius: Colors.radiusSmall
                                color: root.levelColor(coreCol.pct, 70, 90)

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
        // Same reasoning as the quick-stats cards above: four fixed rows
        // whose icon/label never change, written out directly instead of
        // through a Repeater over an array literal that gets rebuilt (and
        // all its delegates destroyed/recreated) on every stats tick.
        Row {
            width: parent.width
            spacing: 24

            Column {
                width: (parent.width - 24) / 2
                spacing: 4

                StyledText { text: "Disk"; font.bold: true; font.pixelSize: Config.fontSize - 1 }

                Item {
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
                            MaterialIcon { anchors.centerIn: parent; icon: "arrow_downward"; font.pixelSize: 13; opacity: 0.7 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            StyledText { text: "Read"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                            StyledText { text: (root.stats.disk.read_mb / 1024).toFixed(1) + " GB"; font.bold: true; font.family: Config.monoFontFamily }
                        }
                    }
                }

                Item {
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
                            MaterialIcon { anchors.centerIn: parent; icon: "arrow_upward"; font.pixelSize: 13; opacity: 0.7 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            StyledText { text: "Write"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                            StyledText { text: (root.stats.disk.write_mb / 1024).toFixed(1) + " GB"; font.bold: true; font.family: Config.monoFontFamily }
                        }
                    }
                }
            }

            Column {
                width: (parent.width - 24) / 2
                spacing: 4

                StyledText { text: "Network"; font.bold: true; font.pixelSize: Config.fontSize - 1 }

                Item {
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
                            MaterialIcon { anchors.centerIn: parent; icon: "arrow_upward"; font.pixelSize: 13; opacity: 0.7 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            StyledText { text: "Sent"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                            StyledText { text: (root.stats.network.sent_mb / 1024).toFixed(1) + " GB"; font.bold: true; font.family: Config.monoFontFamily }
                        }
                    }
                }

                Item {
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
                            MaterialIcon { anchors.centerIn: parent; icon: "arrow_downward"; font.pixelSize: 13; opacity: 0.7 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            StyledText { text: "Received"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                            StyledText { text: (root.stats.network.received_mb / 1024).toFixed(1) + " GB"; font.bold: true; font.family: Config.monoFontFamily }
                        }
                    }
                }
            }
        }

        // --- Network activity sparkline --------------------------------------
        Column {
            width: parent.width
            spacing: 6
            visible: root.stats.networkReceivedHistory.length > 1

            Item {
                width: parent.width
                height: 16
                StyledText { anchors.left: parent.left; text: "Network Activity"; font.bold: true; font.pixelSize: Config.fontSize - 2 }
                StyledText {
                    anchors.right: parent.right
                    text: "↓ " + root.stats.networkRate.receivedKBs.toFixed(1) + " KB/s · ↑ " + root.stats.networkRate.sentKBs.toFixed(1) + " KB/s"
                    opacity: 0.5
                    font.pixelSize: Config.fontSize - 3
                    font.family: Config.monoFontFamily
                }
            }

            Sparkline {
                width: parent.width
                barHeight: 28
                values: root.stats.networkReceivedHistory
                barColor: Colors.accent
            }
        }

        // --- Top processes ----------------------------------------------------
        Column {
            width: parent.width
            spacing: 8
            visible: root.stats.processes.length > 0

            StyledText { text: "Top Processes"; font.bold: true; font.pixelSize: Config.fontSize - 1 }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.stats.processes

                    Item {
                        required property var modelData
                        width: parent.width
                        height: 28

                        Row {
                            anchors.fill: parent
                            spacing: 10

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 130
                                elide: Text.ElideRight
                                text: modelData.name
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 55
                                horizontalAlignment: Text.AlignRight
                                text: modelData.cpu_percent.toFixed(1) + "%"
                                color: root.levelColor(modelData.cpu_percent, 50, 80)
                                font.family: Config.monoFontFamily
                                font.pixelSize: Config.fontSize - 2
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 55
                                horizontalAlignment: Text.AlignRight
                                text: modelData.memory_percent.toFixed(1) + "%"
                                opacity: 0.5
                                font.pixelSize: Config.fontSize - 3
                                font.family: Config.monoFontFamily
                            }
                        }
                    }
                }
            }
        }

        // --- Battery (laptop only) -------------------------------------------
        Column {
            width: parent.width
            spacing: 6
            visible: BatteryHistory.available

            Item {
                width: parent.width
                height: 16
                StyledText { anchors.left: parent.left; text: "Battery"; font.bold: true; font.pixelSize: Config.fontSize - 2 }
                StyledText {
                    anchors.right: parent.right
                    text: BatteryHistory.samples.length > 0
                        ? BatteryHistory.samples[BatteryHistory.samples.length - 1].percent + "%" : "—"
                    opacity: 0.5
                    font.pixelSize: Config.fontSize - 3
                    font.family: Config.monoFontFamily
                }
            }

            Sparkline {
                width: parent.width
                barHeight: 28
                values: BatteryHistory.samples.map(s => s.percent)
                barColor: Colors.accent
            }
        }
    }
}
