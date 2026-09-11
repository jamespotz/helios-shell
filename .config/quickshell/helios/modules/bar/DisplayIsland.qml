import QtQuick
import "../../services"
import "../../components"

// Display settings panel — shows connected monitors with resolution,
// refresh rate, scale, and basic controls.
Item {
    id: root

    readonly property var vrrModes: [
        { value: -1, label: "Global" },
        { value: 0, label: "Off" },
        { value: 1, label: "On" },
        { value: 2, label: "Fullscreen" },
        { value: 3, label: "Video/game" }
    ]

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

        // Monitors — flat layout, no card container, so a single connected
        // display reads as part of the panel instead of a boxed-off widget.
        Repeater {
            model: DisplaySettings.monitors

            Column {
                id: monCol
                required property var modelData
                required property int index

                width: col.width
                spacing: 16
                opacity: monCol.modelData.disabled ? 0.5 : 1
                Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                // Monitor name + status
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: monCol.modelData.disabled ? Colors.overlay : Colors.success
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: monCol.modelData.name
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        visible: monCol.modelData.description && monCol.modelData.description.length > 0
                        text: monCol.modelData.description || ""
                        font.pixelSize: Config.fontSize - 2
                        color: Colors.subtext
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 160)
                        elide: Text.ElideRight
                    }
                }

                // Resolution + refresh rate — prominent stat pairs
                Row {
                    spacing: 32

                    Column {
                        spacing: 2
                        StyledText { text: "Resolution"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
                        StyledText {
                            text: monCol.modelData.width + " × " + monCol.modelData.height
                            font.weight: Font.DemiBold
                            font.pixelSize: Config.fontSize + 2
                        }
                    }

                    Column {
                        spacing: 2
                        StyledText { text: "Refresh rate"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }
                        StyledText {
                            text: Math.round(monCol.modelData.refreshRate) + " Hz"
                            font.weight: Font.DemiBold
                            font.pixelSize: Config.fontSize + 2
                        }
                    }
                }

                // Mode picker — every modeline the monitor reports via
                // hyprctl, queried lazily (only while expanded) since a
                // monitor can report dozens of them.
                Disclosure {
                    id: modeDisclosure
                    width: parent.width
                    title: "Change Resolution"
                    summary: monCol.modelData.width + "×" + monCol.modelData.height + "@" + Math.round(monCol.modelData.refreshRate) + "Hz"
                    onOpenChanged: if (open) DisplaySettings.queryModes(monCol.modelData.name)

                    StyledText {
                        visible: DisplaySettings.modesLoading
                        text: "Loading modes…"
                        color: Colors.subtext
                        font.pixelSize: Config.fontSize - 2
                    }

                    Item {
                        width: parent.width
                        height: 200
                        visible: !DisplaySettings.modesLoading

                        ListView {
                            id: modeList
                            anchors.fill: parent
                            clip: true
                            model: DisplaySettings.availableModes
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: modeRow
                                required property string modelData

                                readonly property bool active: modeRow.modelData.toLowerCase() === (
                                    monCol.modelData.width + "x" + monCol.modelData.height + "@" + monCol.modelData.refreshRate.toFixed(2) + "hz")

                                width: modeList.width
                                height: 32
                                radius: 8
                                color: active ? Colors.accent : (modeHover.hovered ? Colors.surfaceHigh : "transparent")

                                Behavior on color { ColorAnimation { duration: Config.animFast } }

                                HoverHandler { id: modeHover }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modeRow.modelData
                                    font.pixelSize: Config.fontSize - 1
                                    color: modeRow.active ? Colors.accentText : Colors.text
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: DisplaySettings.setResolutionMode(monCol.modelData.name, modeRow.modelData)
                                }
                            }
                        }

                        ScrollIndicator { target: modeList }
                    }
                }

                // Scale
                Column {
                    width: parent.width
                    spacing: 8

                    StyledText { text: "Scale"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }

                    Row {
                        spacing: 6

                        Repeater {
                            model: [1.0, 1.25, 1.5, 1.75, 2.0]

                            Chip {
                                required property var modelData
                                active: Math.abs(monCol.modelData.scale - modelData) < 0.01
                                text: modelData + "×"
                                onClicked: DisplaySettings.setScale(monCol.modelData.name, modelData)
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8

                    StyledText { text: "Adaptive Sync"; font.pixelSize: Config.fontSize - 2; color: Colors.subtext }

                    Flow {
                        width: parent.width
                        height: childrenRect.height
                        spacing: 6

                        Repeater {
                            model: root.vrrModes

                            Chip {
                                required property var modelData
                                active: Number(monCol.modelData.vrrMode) === modelData.value
                                text: modelData.label
                                onClicked: DisplaySettings.setVrr(monCol.modelData.name, modelData.value)
                            }
                        }
                    }
                }

                ToggleRow {
                    width: parent.width
                    title: "HDR"
                    subtitle: "10-bit HDR PQ output. Experimental in Hyprland."
                    checked: monCol.modelData.colorManagementPreset === "hdr"
                        || monCol.modelData.colorManagementPreset === "hdredid"
                    onToggled: enabled => DisplaySettings.setHdr(monCol.modelData.name, enabled)
                }
            }
        }
    }
}
