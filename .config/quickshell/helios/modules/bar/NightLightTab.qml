import QtQuick
import "../../services"
import "../../components"

// Night Light panel — toggle + temperature slider + schedule option.
// Apple-style: warm gradient preview, clear on/off state, simple slider.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: col.implicitHeight + 8

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 14

        // Header with toggle
        Row {
            width: parent.width
            spacing: 10

            MaterialIcon {
                icon: "nightlight"
                font.pixelSize: 20
                color: NightLight.enabled ? Colors.warning : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 - 10 - toggle.width - 10
                StyledText { text: "Night Light"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 1 }
                StyledText { text: "Reduces blue light to ease eye strain"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
            }

            Toggle {
                id: toggle
                anchors.verticalCenter: parent.verticalCenter
                checked: NightLight.enabled
                onToggled: v => NightLight.setEnabled(v)
            }
        }

        // Temperature preview gradient
        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            opacity: NightLight.enabled ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#ff8c2d" }
                GradientStop { position: 0.5; color: "#ffc87a" }
                GradientStop { position: 1.0; color: "#ffffff" }
            }
        }

        // Temperature slider
        Column {
            width: parent.width
            spacing: 6
            opacity: NightLight.enabled ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

            Row {
                width: parent.width
                StyledText { text: "Warmth"; font.weight: Font.Medium }
                Item { width: parent.width - parent.children[0].implicitWidth - tempLabel.implicitWidth; height: 1 }
                StyledText { id: tempLabel; text: NightLight.temperature + "K"; color: Colors.subtext; font.pixelSize: Config.fontSize - 1 }
            }

            Slider {
                width: parent.width
                value: NightLight.tempMax - NightLight.temperature  // Inverted: left = warm
                maxValue: NightLight.tempMax - NightLight.tempMin
                fillColor: Colors.warning
                onMoved: v => NightLight.setTemperature(NightLight.tempMax - Math.round(v))
            }

            Row {
                width: parent.width
                StyledText { text: "Warmer"; font.pixelSize: Config.fontSize - 3; color: Colors.subtext }
                Item { width: parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth; height: 1 }
                StyledText { text: "Cooler"; font.pixelSize: Config.fontSize - 3; color: Colors.subtext }
            }
        }

        // Separator
        Rectangle { width: parent.width; height: 0.5; color: Colors.overlay; opacity: 0.3 }

        // Schedule toggle
        Row {
            width: parent.width
            opacity: NightLight.enabled ? 1 : 0.4

            Column {
                width: parent.width - schedToggle.width - 10
                anchors.verticalCenter: parent.verticalCenter
                StyledText { text: "Sunset to Sunrise"; font.weight: Font.Medium }
                StyledText { text: "Automatically enable based on location"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
            }

            Toggle {
                id: schedToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: NightLight.scheduled
                onToggled: v => NightLight.setScheduled(v)
            }
        }

        // Location hint
        StyledText {
            visible: NightLight.enabled && NightLight.scheduled && NightLight.latitude === 0
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: Config.fontSize - 2
            color: Colors.warning
            text: "Set latitude/longitude via IPC: quickshell -c helios ipc call nightlight location <lat> <lon>"
        }
    }
}
