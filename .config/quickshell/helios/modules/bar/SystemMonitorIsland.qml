import QtQuick
import "../../services"
import "../../components"
import "systemmonitor"

// Live system resource monitor — a grid of cards (storage, battery or GPU,
// CPU, memory, network, temperature, controls) from systemmonitor/. Backed
// by services/SystemStats.qml, which spawns modules/bar/system-info.py
// (psutil + nvidia-smi) only while this tab is open.
Item {
    id: root

    readonly property var stats: SystemStats.state

    property bool live: true
    onLiveChanged: SystemStats.setActive(root.live)

    // "dashboard" is the stats overview below; "processes" swaps in the
    // full sortable/filterable Process List in place, rather than adding a
    // 20th entry to PanelWrapper's already-crowded tab bar.
    property string view: "dashboard"
    onViewChanged: SystemStats.setProcessDetail(root.view === "processes")

    Component.onCompleted: SystemStats.setActive(true)
    Component.onDestruction: SystemStats.setActive(false)

    implicitWidth: 620
    implicitHeight: root.view === "dashboard" ? col.implicitHeight : processView.implicitHeight

    ProcessListView {
        id: processView
        width: parent.width
        visible: root.view === "processes"
        onBackRequested: root.view = "dashboard"
    }

    Column {
        id: col
        width: parent.width
        spacing: 12
        visible: root.view === "dashboard"

        // --- Header: live indicator + pause toggle --------------------------
        Item {
            width: parent.width
            height: 28

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                MaterialIcon { icon: "memory"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: "System Monitor"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.success
                    opacity: root.live ? 1 : 0.35

                    SequentialAnimation on opacity {
                        running: root.live && !Config.reducedMotion
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

        // --- Cards ------------------------------------------------------------
        // Two-card rows share the taller card's height; the slot beside
        // Storage is Battery on laptops, GPU on desktops, and collapses
        // (Storage goes full width) when neither exists.
        Row {
            id: topRow
            readonly property bool slotVisible: batteryCard.visible || gpuCard.visible
            width: parent.width
            spacing: 12

            StorageCard {
                id: storageCard
                width: topRow.slotVisible ? (topRow.width - topRow.spacing) / 2 : topRow.width
                height: Math.max(implicitHeight, batteryCard.visible ? batteryCard.implicitHeight : 0, gpuCard.visible ? gpuCard.implicitHeight : 0)
            }
            BatteryCard {
                id: batteryCard
                visible: BatteryHistory.available
                width: storageCard.width
                height: storageCard.height
            }
            GpuCard {
                id: gpuCard
                visible: !BatteryHistory.available && !!root.stats.gpu
                width: storageCard.width
                height: storageCard.height
            }
        }

        CpuCard {
            width: parent.width
            height: implicitHeight
            showGpuLine: BatteryHistory.available
            onActionTriggered: root.view = "processes"
        }

        Row {
            width: parent.width
            spacing: 12

            MemoryCard {
                id: memoryCard
                width: (parent.width - parent.spacing) / 2
                height: Math.max(implicitHeight, networkCard.implicitHeight)
            }
            NetworkCard {
                id: networkCard
                width: memoryCard.width
                height: memoryCard.height
            }
        }

        Row {
            width: parent.width
            spacing: 12

            TemperatureCard {
                id: temperatureCard
                width: (parent.width - parent.spacing) / 2
                height: Math.max(implicitHeight, controlsCard.implicitHeight)
            }
            ControlsCard {
                id: controlsCard
                width: temperatureCard.width
                height: temperatureCard.height
            }
        }
    }
}
