import QtQuick
import "../services"

// Wi-Fi/Bluetooth pill switcher + power button shown under the orbit view —
// shared by BluetoothTab and WifiTab so switching between the two islands
// doesn't require leaving the panel. Caller sets width/visible.
Row {
    id: root
    spacing: 10

    Rectangle {
        width: parent.width - 44 - 10
        height: 44
        radius: 22
        color: Colors.surfaceHigh

        Row {
            anchors.fill: parent
            anchors.margins: 3

            Rectangle {
                width: parent.width / 2
                height: parent.height
                radius: 19
                color: Bridge.islandTab === "wifi" ? Colors.surface : "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon { icon: "wifi"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                    StyledText { text: "Wi-Fi"; anchors.verticalCenter: parent.verticalCenter }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.surfaceHigh
                    opacity: wifiPillHover.hovered && Bridge.islandTab !== "wifi" ? 0.25 : 0
                }

                HoverHandler { id: wifiPillHover }

                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Bridge.setIslandTab("wifi") }
            }

            Rectangle {
                width: parent.width / 2
                height: parent.height
                radius: 19
                color: Bridge.islandTab === "bluetooth" ? Colors.secondary : "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon {
                        icon: "bluetooth"
                        font.pixelSize: 15
                        color: Bridge.islandTab === "bluetooth" ? Colors.secondaryText : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: "Bluetooth"
                        color: Bridge.islandTab === "bluetooth" ? Colors.secondaryText : Colors.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.surfaceHigh
                    opacity: btPillHover.hovered && Bridge.islandTab !== "bluetooth" ? 0.25 : 0
                }

                HoverHandler { id: btPillHover }

                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Bridge.setIslandTab("bluetooth") }
            }
        }
    }

    IconButton {
        width: 44
        height: 44
        active: true
        icon: "power_settings_new"
        iconSize: 18
        onClicked: Bridge.togglePowerMenu()
    }
}
