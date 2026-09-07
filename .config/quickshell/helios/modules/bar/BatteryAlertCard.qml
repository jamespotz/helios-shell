import QtQuick
import "../../services"
import "../../components"

// Auto-peek card for a Bluetooth device dropping below Bluetooth.qml's
// lowBatteryThreshold — device continuity's "warn only when action
// matters" piece. Same shape as MeetingCard.qml/TaskCard.qml: Bar.qml
// surfaces it via batteryMode, this just renders Bluetooth.lowBatteryAlert.
Item {
    id: root

    readonly property var device: Bluetooth.lowBatteryAlert
    readonly property int percent: root.device && root.device.batteryAvailable ? Math.round(root.device.battery * 100) : 0

    implicitWidth: Config.notifyWidth
    implicitHeight: rowLayout.implicitHeight

    HoverHandler { id: hoverTracker }

    Timer {
        id: autoDismissTimer
        interval: 10000
        running: root.device !== null
        onTriggered: {
            if (hoverTracker.hovered) { autoDismissTimer.restart(); return; }
            Bluetooth.dismissLowBattery();
        }
    }

    Row {
        id: rowLayout
        width: parent.width
        spacing: 12

        MaterialIcon {
            icon: "battery_alert"
            font.pixelSize: 20
            color: Colors.danger
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - 20 - 12 - closeBtn.width - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                font.weight: Font.DemiBold
                text: root.device ? root.device.name : ""
            }
            StyledText {
                color: Colors.danger
                font.pixelSize: Config.fontSize - 2
                text: root.percent + "% battery"
            }
        }

        IconButton {
            id: closeBtn
            anchors.verticalCenter: parent.verticalCenter
            icon: "close"
            iconSize: 14
            onClicked: Bluetooth.dismissLowBattery()
        }
    }
}
