import QtQuick
import "../../services"
import "../../components"

// Automation rules — a handful of concrete trigger/action toggles (see
// services/Automations.qml), not a rule builder. Same toggle-row shape as
// NightLightIsland.qml for a setting with a one-line description.
Item {
    id: root

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 8

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 16

        Row {
            width: parent.width
            spacing: 10

            MaterialIcon {
                icon: "headphones"
                font.pixelSize: 20
                color: Automations.headphonesRule ? Colors.accent : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                width: parent.width - 20 - 10 - headphonesToggle.width - 10
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Headphones Connect"; font.weight: Font.DemiBold }
                StyledText { text: "Opens media controls"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
            }
            Toggle {
                id: headphonesToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: Automations.headphonesRule
                onToggled: v => Automations.setHeadphonesRule(v)
            }
        }

        Row {
            width: parent.width
            spacing: 10

            MaterialIcon {
                icon: "desktop_windows"
                font.pixelSize: 20
                color: Automations.monitorRule ? Colors.accent : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                width: parent.width - 20 - 10 - monitorToggle.width - 10
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "External Monitor Connects"; font.weight: Font.DemiBold }
                StyledText { text: "Restores its last resolution, scale, and VRR"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext; wrapMode: Text.WordWrap; width: parent.width }
            }
            Toggle {
                id: monitorToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: Automations.monitorRule
                onToggled: v => Automations.setMonitorRule(v)
            }
        }

        Row {
            width: parent.width
            spacing: 10

            MaterialIcon {
                icon: "battery_alert"
                font.pixelSize: 20
                color: Automations.batteryRule ? Colors.accent : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                width: parent.width - 20 - 10 - batteryToggle.width - 10
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Battery Below 20%"; font.weight: Font.DemiBold }
                StyledText { text: "Enables Power Saver"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
            }
            Toggle {
                id: batteryToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: Automations.batteryRule
                onToggled: v => Automations.setBatteryRule(v)
            }
        }

        Rectangle { width: parent.width; height: 0.5; color: Colors.overlay; opacity: 0.3 }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Meeting starts → Do Not Disturb is set from Focus Modes' calendar picker, in the Calendar tab."
            font.pixelSize: Config.fontSize - 3
            color: Colors.subtext
            opacity: 0.8
        }
    }
}
