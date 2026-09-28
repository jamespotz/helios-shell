import QtQuick
import "../../../services"
import "../../../components"

MonitorCard {
    id: root

    readonly property var stats: SystemStats.state
    readonly property var storage: root.stats.storage

    value: root.storage ? root.storage.free_gb.toFixed(1) : "—"
    unit: root.storage ? "GB" : ""
    label: "Available Storage"
    icon: "hard_drive"
    footerText: root.storage ? root.storage.mount + " · " + root.storage.total_gb.toFixed(0) + " GB" : ""
    actionText: "Analyze"
    actionVisible: SystemStats.diskAnalyzer.length > 0
    onActionTriggered: AppLaunch.exec([SystemStats.diskAnalyzer])

    Meter {
        width: parent.width
        percent: root.storage ? root.storage.percent : 0
        fillColor: root.levelColor(percent, 80, 92)
    }
    StyledText {
        text: root.storage ? root.storage.used_gb.toFixed(1) + " GB Used" : ""
        font.pixelSize: Config.fontSize - 2
    }
    RateRow {
        downBytesPerSec: root.stats.diskRate.readKBs * 1024
        upBytesPerSec: root.stats.diskRate.writeKBs * 1024
    }
}
