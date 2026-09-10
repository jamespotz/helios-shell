import QtQuick
import "../../services"
import "../../components"

// Display settings panel — shows connected monitors with resolution,
// refresh rate, scale, and basic controls.
Item {
    id: root

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // Header
        Row {
            width: parent.width
            spacing: 8

            MaterialIcon { icon: "monitor"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Displays"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }

            Item { width: parent.width - parent.children[0].width - parent.children[1].width - 16 - refreshBtn.width; height: 1 }

            IconButton {
                id: refreshBtn
                icon: "refresh"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: DisplaySettings.refresh()
            }
        }

        // Loading state
        StyledText {
            visible: DisplaySettings.loading
            text: "Scanning displays…"
            color: Colors.subtext
        }

        // No monitors
        StyledText {
            visible: !DisplaySettings.loading && DisplaySettings.monitors.length === 0
            text: "No displays detected"
            color: Colors.subtext
        }

        // Monitor cards
        Repeater {
            model: DisplaySettings.monitors

            Rectangle {
                id: monCard
                required property var modelData
                required property int index

                width: col.width
                height: monCol.implicitHeight + 20
                radius: Colors.radiusLarge
                color: Colors.surfaceHigh
                opacity: monCard.modelData.disabled ? 0.5 : 1
                Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                Column {
                    id: monCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // Monitor name + status
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: monCard.modelData.disabled ? Colors.overlay : Colors.success
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: monCard.modelData.name
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            visible: monCard.modelData.description && monCard.modelData.description.length > 0
                            text: monCard.modelData.description || ""
                            font.pixelSize: Config.fontSize - 2
                            color: Colors.subtext
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 140)
                            elide: Text.ElideRight
                        }
                    }

                    // Resolution + refresh
                    Row {
                        spacing: 16

                        Column {
                            spacing: 2
                            StyledText { text: "Resolution"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
                            StyledText {
                                text: monCard.modelData.width + " × " + monCard.modelData.height
                                font.weight: Font.Medium
                            }
                        }

                        Column {
                            spacing: 2
                            StyledText { text: "Refresh"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
                            StyledText {
                                text: Math.round(monCard.modelData.refreshRate) + " Hz"
                                font.weight: Font.Medium
                            }
                        }

                        Column {
                            spacing: 2
                            StyledText { text: "Scale"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
                            StyledText {
                                text: monCard.modelData.scale + "×"
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // Scale controls
                    Row {
                        spacing: 6

                        StyledText { text: "Scale:"; font.pixelSize: Config.fontSize - 1; anchors.verticalCenter: parent.verticalCenter }

                        Repeater {
                            model: [1.0, 1.25, 1.5, 1.75, 2.0]

                            Chip {
                                required property var modelData
                                active: Math.abs(monCard.modelData.scale - modelData) < 0.01
                                text: modelData + "×"
                                onClicked: DisplaySettings.setScale(monCard.modelData.name, modelData)
                            }
                        }
                    }

                    // VRR toggle
                    Row {
                        width: parent.width

                        StyledText {
                            text: "Adaptive Sync (VRR)"
                            font.pixelSize: Config.fontSize - 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - vrrToggle.width
                        }

                        Toggle {
                            id: vrrToggle
                            anchors.verticalCenter: parent.verticalCenter
                            checked: monCard.modelData.vrr !== undefined && monCard.modelData.vrr > 0
                            onToggled: v => DisplaySettings.setVrr(monCard.modelData.name, v ? 1 : 0)
                        }
                    }
                }
            }
        }
    }
}
