import QtQuick
import "../../../services"
import "../../../components"

MonitorCard {
    id: root

    readonly property var sensors: SystemStats.state.sensors
    readonly property var gpu: SystemStats.state.gpu
    readonly property bool hasTemp: root.sensors.cpu_c !== null
    readonly property real temp: root.hasTemp ? root.sensors.cpu_c : 0
    readonly property color tempColor: root.levelColor(root.temp, 70, 85)

    value: root.hasTemp ? root.temp.toFixed(0) : "—"
    unit: root.hasTemp ? "°C" : ""
    label: "CPU Temperature"
    icon: "thermostat"
    iconColor: root.hasTemp ? root.tempColor : Colors.text

    Meter {
        width: parent.width
        visible: root.hasTemp
        percent: root.temp
        fillColor: root.tempColor
    }
    StatRow {
        width: parent.width
        visible: !!root.gpu
        icon: "developer_board"
        label: "GPU"
        value: root.gpu ? root.gpu.temperature_c.toFixed(0) + "°C" : ""
    }
    StatRow {
        width: parent.width
        visible: root.sensors.fan_rpm !== null
        icon: "mode_fan"
        label: "Fan"
        value: (root.sensors.fan_rpm || 0).toLocaleString(Qt.locale(), "f", 0) + " RPM"
    }
    Row {
        visible: root.hasTemp
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: root.temp >= 70 ? root.tempColor : Colors.success
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Thermal state"
            opacity: 0.7
            font.pixelSize: Config.fontSize - 2
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temp >= 85 ? "Serious" : root.temp >= 70 ? "Fair" : "Nominal"
            font.pixelSize: Config.fontSize - 2
            font.weight: Font.Medium
        }
    }
}
