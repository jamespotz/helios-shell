import QtQuick
import Quickshell.Services.UPower
import "../../../services"
import "../../../components"

MonitorCard {
    id: root

    readonly property var device: BatteryHistory.device
    readonly property int percent: root.device ? Math.round(root.device.percentage * 100) : 0
    readonly property bool charging: !!root.device && root.device.state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: !!root.device && (root.device.state === UPowerDeviceState.FullyCharged
        || root.device.state === UPowerDeviceState.PendingCharge)

    value: String(root.percent)
    unit: "%"
    label: "Battery Remaining"
    icon: root.charging ? "battery_charging_full" : "battery_full"

    Meter {
        width: parent.width
        percent: root.percent
        fillColor: root.percent <= 10 ? Colors.danger : root.percent <= 20 ? Colors.warning : Colors.success
    }
    StyledText {
        text: root.charging ? "Charging" : root.pluggedIn ? "Plugged In" : "On Battery"
        font.pixelSize: Config.fontSize - 2
    }
}
