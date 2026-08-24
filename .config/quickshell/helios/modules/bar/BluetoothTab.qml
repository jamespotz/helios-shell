import QtQuick
import Quickshell.Bluetooth
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedDevice: root.devices.find(d => d.connected) || null

    // "orbit" is the focused single-device view from the mockup; "list"
    // is the old flat device list, still useful with several paired devices.
    property string viewMode: root.connectedDevice ? "orbit" : "list"

    // Which device (by address) has its auto-connect switch expanded open in
    // list mode — pressing a device's row toggles this rather than showing
    // it always, to keep the list compact.
    property string expandedDevice: ""

    implicitWidth: 720
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        Item {
            width: parent.width
            height: 24

            MaterialIcon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: root.adapter && root.adapter.enabled ? "bluetooth" : "bluetooth_disabled"
            }
            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 26
                anchors.verticalCenter: parent.verticalCenter
                text: root.adapter
                    ? (root.adapter.enabled ? (root.adapter.discovering ? "Scanning…" : "On") : "Off")
                    : "No adapter"
            }
            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.adapter ? root.adapter.enabled : false
                enabled: !!root.adapter
                onToggled: v => { if (root.adapter) root.adapter.enabled = v }
            }
        }

        // --- Orbit view: focused view of the connected device ------------------
        Item {
            width: parent.width
            height: 460
            visible: root.viewMode === "orbit" && root.adapter && root.adapter.enabled

            Item {
                id: orbitCenter
                anchors.centerIn: parent
                width: 1
                height: 1

                Repeater {
                    model: [90, 140, 190]
                    Rectangle {
                        required property int modelData
                        anchors.centerIn: parent
                        width: modelData * 2
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Colors.overlay
                        opacity: 0.25
                    }
                }

                Rectangle {
                    id: centerCircle
                    anchors.centerIn: parent
                    width: 150
                    height: 150
                    radius: 75
                    color: Colors.secondary

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialIcon {
                            icon: "headset"
                            font.pixelSize: 40
                            color: Colors.secondaryText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: root.connectedDevice ? (root.connectedDevice.name || root.connectedDevice.deviceName) : "No device"
                            color: Colors.secondaryText
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: root.connectedDevice ? "Connected" : "Not connected"
                            color: Colors.secondaryText
                            opacity: 0.75
                            font.pixelSize: Config.fontSize - 2
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // --- Satellite cards ---------------------------------------------
                Rectangle {
                    id: scanCard
                    width: 190
                    height: 56
                    radius: Colors.radiusLarge
                    color: Colors.surfaceHigh
                    x: -width / 2
                    y: -190

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        MaterialIcon { icon: "search"; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 2
                            StyledText { text: "Scan Devices"; font.bold: true; font.pixelSize: Config.fontSize - 1 }
                            StyledText { text: "Switch View"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colors.surfaceHigh
                        opacity: scanCardHover.hovered ? 0.15 : 0
                    }

                    HoverHandler { id: scanCardHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.adapter) root.adapter.discovering = !root.adapter.discovering
                    }
                    MouseArea {
                        // "Switch View" label only
                        height: 18
                        anchors.left: parent.left
                        anchors.leftMargin: 40
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        width: 90
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.viewMode = "list"
                    }
                }

                Rectangle {
                    width: 180
                    height: 56
                    radius: Colors.radiusLarge
                    color: Colors.surfaceHigh
                    x: -320
                    y: -28

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        MaterialIcon { icon: "dns"; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 2
                            StyledText {
                                text: root.connectedDevice ? root.connectedDevice.address : "—"
                                font.bold: true
                                font.family: Config.monoFontFamily
                                font.pixelSize: Config.fontSize - 2
                            }
                            StyledText { text: "MAC Address"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                        }
                    }
                }

                Rectangle {
                    width: 180
                    height: 56
                    radius: Colors.radiusLarge
                    color: Colors.surfaceHigh
                    x: 140
                    y: -28

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        MaterialIcon { icon: "battery_full"; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 2
                            StyledText {
                                text: root.connectedDevice && root.connectedDevice.batteryAvailable
                                    ? Math.round(root.connectedDevice.battery * 100) + "%" : "—"
                                font.bold: true
                                font.pixelSize: Config.fontSize - 1
                            }
                            StyledText { text: "Battery"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                        }
                    }
                }

                Rectangle {
                    width: 190
                    height: 56
                    radius: Colors.radiusLarge
                    color: Colors.surfaceHigh
                    x: -width / 2
                    y: 130

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        MaterialIcon { icon: "graphic_eq"; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 2
                            // Bluez doesn't expose a codec/audio-profile string
                            // through this service today — placeholder until
                            // that's wired up (likely via WirePlumber).
                            StyledText { text: "None"; font.bold: true; font.pixelSize: Config.fontSize - 1 }
                            StyledText { text: "Audio Profile"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: root.viewMode === "orbit" && root.adapter && root.adapter.enabled && root.devices.length === 0
            text: "No devices found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        // --- Bottom bar: Wi-Fi / Bluetooth switch + power -----------------------
        Row {
            width: parent.width
            visible: root.viewMode === "orbit"
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

            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: Colors.accent

                MaterialIcon { anchors.centerIn: parent; icon: "power_settings_new"; color: Colors.accentText }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.surfaceHigh
                    opacity: powerBtnHover.hovered ? 0.25 : 0
                }

                HoverHandler { id: powerBtnHover }

                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Bridge.togglePowerMenu() }
            }
        }

        // --- List view: original flat device list -------------------------------
        ListView {
            id: deviceList
            width: parent.width - 8
            visible: root.viewMode === "list" && root.adapter && root.adapter.enabled
            height: visible ? Math.min(300, Math.max(0, root.devices.length * 46)) : 0
            clip: true
            spacing: 4
            model: root.devices
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: deviceList }

            delegate: Column {
                id: row
                required property var modelData
                required property int index

                readonly property bool expanded: root.expandedDevice === modelData.address

                width: deviceList.width
                spacing: 2

                HoverRow {
                    id: card
                    width: parent.width
                    height: 40
                    highlighted: row.modelData.connected
                    onClicked: root.expandedDevice = row.expanded ? "" : row.modelData.address

                    Row {
                        anchors.left: parent.left
                        anchors.right: connectIcon.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: 8

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: row.modelData.connected ? "bluetooth_connected"
                                : row.modelData.pairing ? "bluetooth_searching" : "bluetooth"
                            font.pixelSize: 16
                        }

                        StyledText {
                            width: parent.width - 24
                            elide: Text.ElideRight
                            text: (row.modelData.name || row.modelData.deviceName || row.modelData.address)
                                + (row.modelData.batteryAvailable ? "  ·  " + Math.round(row.modelData.battery * 100) + "%" : "")
                        }
                    }

                    MaterialIcon {
                        id: connectIcon
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        icon: row.modelData.connected ? "link_off"
                            : row.modelData.pairing ? "bluetooth_searching" : "link"
                        color: row.modelData.connected ? Colors.danger : Colors.secondary
                        font.pixelSize: 18

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -2
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (row.modelData.connected) row.modelData.disconnect();
                                else if (row.modelData.paired) row.modelData.connect();
                                else row.modelData.pair();
                            }
                        }
                    }
                }

                Item {
                    visible: row.expanded
                    width: parent.width
                    height: 22

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Auto-connect"
                        opacity: 0.6
                        font.pixelSize: Config.fontSize - 2
                    }

                    Toggle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: row.modelData.trusted
                        onToggled: v => row.modelData.trusted = v
                    }
                }
            }
        }

        Item {
            width: switchRow.implicitWidth
            height: switchRow.implicitHeight
            visible: root.viewMode === "list" && root.adapter && root.adapter.enabled && !!root.connectedDevice

            Row {
                id: switchRow
                spacing: 6
                opacity: orbitLinkHover.hovered ? 1 : 0.7
                MaterialIcon { icon: "blur_on"; font.pixelSize: 14 }
                StyledText { text: "Switch to orbit view"; font.pixelSize: Config.fontSize - 2 }
            }

            MouseArea {
                id: orbitLinkHover
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.viewMode = "orbit"
            }
        }
    }
}
