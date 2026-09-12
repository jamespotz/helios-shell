import QtQuick
import "../../services"
import "../../components"

// Idle & Lock settings panel — configure auto-lock, screen dimming,
// and DPMS timeouts. Includes a "caffeine" toggle to temporarily
// prevent the screen from sleeping.
Item {
    id: root

    implicitWidth: 320
    implicitHeight: col.implicitHeight + 12

    function formatTime(secs) {
        if (secs === 0) return "Never";
        if (secs < 60) return secs + "s";
        const m = Math.floor(secs / 60);
        if (m < 60) return m + " min";
        const h = Math.floor(m / 60);
        return h + "h " + (m % 60) + "m";
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 16

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "bedtime"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Idle & Lock"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 1; anchors.verticalCenter: parent.verticalCenter }
        }

        // Caffeine mode — temporary inhibit
        Rectangle {
            width: col.width
            height: 52
            radius: 12
            color: IdleInhibit.inhibited ? Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.15) : Colors.surfaceHigh
            opacity: IdleInhibit.inhibited ? 1 : 0.5

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                MaterialIcon {
                    icon: "coffee"
                    font.pixelSize: 18
                    color: IdleInhibit.inhibited ? Colors.warning : Colors.text
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 18 - 10 - caffeineToggle.width - 10
                    StyledText { text: "Caffeine Mode"; font.weight: Font.Medium }
                    StyledText { text: "Keep screen awake"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
                }

                Toggle {
                    id: caffeineToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: IdleInhibit.inhibited
                    onToggled: IdleInhibit.toggleInhibit()
                }
            }
        }

        // Auto-lock toggle
        Row {
            width: col.width
            height: 28

            StyledText {
                text: "Auto-Lock"
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: col.width - parent.children[0].implicitWidth - enableToggle.width; height: 1 }

            Toggle {
                id: enableToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: IdleInhibit.enabled
                onToggled: v => IdleInhibit.setEnabled(v)
            }
        }

        // Timeout sliders
        Column {
            width: col.width
            spacing: 16
            opacity: IdleInhibit.enabled && !IdleInhibit.inhibited ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

            // Dim timeout
            Column {
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width
                    height: 16
                    StyledText {
                        text: "Dim screen after"
                        font.pixelSize: Config.fontSize - 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item { width: parent.width - parent.children[0].implicitWidth - dimVal.implicitWidth; height: 1 }
                    StyledText {
                        id: dimVal
                        text: root.formatTime(IdleInhibit.dimTimeout)
                        color: Colors.accent
                        font.weight: Font.Medium
                        font.pixelSize: Config.fontSize - 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Slider {
                    width: parent.width
                    value: IdleInhibit.dimTimeout
                    maxValue: 900
                    onMoved: v => IdleInhibit.setDimTimeout(Math.round(v / 30) * 30)
                }
            }

            // Lock timeout
            Column {
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width
                    height: 16
                    StyledText {
                        text: "Lock screen after"
                        font.pixelSize: Config.fontSize - 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item { width: parent.width - parent.children[0].implicitWidth - lockVal.implicitWidth; height: 1 }
                    StyledText {
                        id: lockVal
                        text: root.formatTime(IdleInhibit.lockTimeout)
                        color: Colors.accent
                        font.weight: Font.Medium
                        font.pixelSize: Config.fontSize - 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Slider {
                    width: parent.width
                    value: IdleInhibit.lockTimeout
                    maxValue: 1800
                    onMoved: v => IdleInhibit.setLockTimeout(Math.round(v / 30) * 30)
                }
            }

            // DPMS timeout
            Column {
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width
                    height: 16
                    StyledText {
                        text: "Turn off display after"
                        font.pixelSize: Config.fontSize - 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item { width: parent.width - parent.children[0].implicitWidth - dpmsVal.implicitWidth; height: 1 }
                    StyledText {
                        id: dpmsVal
                        text: root.formatTime(IdleInhibit.dpmsTimeout)
                        color: Colors.accent
                        font.weight: Font.Medium
                        font.pixelSize: Config.fontSize - 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Slider {
                    width: parent.width
                    value: IdleInhibit.dpmsTimeout
                    maxValue: 1800
                    onMoved: v => IdleInhibit.setDpmsTimeout(Math.round(v / 30) * 30)
                }
            }
        }
    }
}
