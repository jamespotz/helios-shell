import QtQuick
import "../../services"
import "../../components"

// Night Light panel — "Comfort" section: toggle + schedule + temperature
// slider. Apple-style: quiet section label, clear on/off state, simple
// slider with no chrome around it.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "nightlight"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Night Light"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        StyledText {
            text: "Comfort"
            font.weight: Font.DemiBold
            font.pixelSize: Config.fontSize - 1
            color: Colors.subtext
        }

        ToggleRow {
            width: parent.width
            title: "Night Light"
            subtitle: "Shifts colors warmer in the evening to ease eye strain"
            checked: NightLight.enabled
            onToggled: v => NightLight.setEnabled(v)
        }

        ToggleRow {
            width: parent.width
            title: "Schedule from sunset to sunrise"
            subtitle: "Uses the location set in Weather"
            checked: NightLight.scheduled
            enabled: NightLight.enabled
            onToggled: v => NightLight.setScheduled(v)
        }

        // Temperature slider
        Column {
            width: parent.width
            spacing: 8
            opacity: NightLight.enabled ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

            Slider {
                width: parent.width
                value: NightLight.tempMax - NightLight.temperature  // Inverted: left = warm
                maxValue: NightLight.tempMax - NightLight.tempMin
                fillColor: Colors.warning
                onMoved: v => NightLight.setTemperature(NightLight.tempMax - Math.round(v))
            }

            Item {
                width: parent.width
                height: warmerLabel.implicitHeight

                StyledText {
                    id: warmerLabel
                    anchors.left: parent.left
                    text: "Warmer"
                    font.pixelSize: Config.fontSize - 3
                    color: Colors.subtext
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: NightLight.temperature + "K"
                    font.pixelSize: Config.fontSize - 2
                    color: Colors.subtext
                }
                StyledText {
                    anchors.right: parent.right
                    text: "Cooler"
                    font.pixelSize: Config.fontSize - 3
                    color: Colors.subtext
                }
            }
        }

        // Location hint
        StyledText {
            visible: NightLight.enabled && NightLight.scheduled && Weather.latitude === 0 && Weather.longitude === 0
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: Config.fontSize - 2
            color: Colors.warning
            text: "No location set — set one in Weather settings to enable scheduling."
        }
    }
}
