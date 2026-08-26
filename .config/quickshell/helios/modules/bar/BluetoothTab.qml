import QtQuick
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var devices: Bluetooth.devices
    readonly property var connectedDevice: root.devices.find(d => d.connected) || null
    readonly property var myDevices: root.devices.filter(d => d.paired)
    readonly property var nearbyDevices: root.devices.filter(d => !d.paired)

    // BlueZ reports XDG icon names (e.g. "audio-headset", "input-keyboard"),
    // not Material Symbols — map the common ones so device rows get a
    // sensible glyph instead of always falling back to the plain bluetooth icon.
    function iconFor(dev) {
        const raw = (dev.icon || "").toLowerCase();
        if (raw.includes("headset") || raw.includes("headphone")) return "headset";
        if (raw.includes("phone")) return "smartphone";
        if (raw.includes("keyboard")) return "keyboard";
        if (raw.includes("mouse")) return "mouse";
        if (raw.includes("audio") || raw.includes("speaker")) return "speaker";
        if (raw.includes("display") || raw.includes("monitor")) return "desktop_windows";
        return dev.connected ? "bluetooth_connected" : "bluetooth";
    }

    // "orbit" is the focused single-device view from the mockup; "list"
    // is the old flat device list, still useful with several paired devices.
    property string viewMode: root.connectedDevice ? "orbit" : "list"

    // Which device (by address) has its auto-connect switch expanded open in
    // list mode — pressing a device's row toggles this rather than showing
    // it always, to keep the list compact.
    property string expandedDevice: ""

    implicitWidth: root.viewMode === "orbit" ? 720 : 320
    implicitHeight: col.implicitHeight

    Component.onCompleted: Bluetooth.open()
    Component.onDestruction: Bluetooth.close()

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
                icon: Bluetooth.powered ? "bluetooth" : "bluetooth_disabled"
            }
            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 26
                anchors.verticalCenter: parent.verticalCenter
                text: !Bluetooth.available ? "No adapter"
                    : (Bluetooth.powered ? (Bluetooth.scanning ? "Scanning…" : "On") : "Off")
            }
            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Bluetooth.powered
                enabled: Bluetooth.available
                onToggled: v => Bluetooth.setPowered(v)
            }
        }

        StyledText {
            visible: Bluetooth.lastError.length > 0
            text: Bluetooth.lastError
            color: Colors.danger
            font.pixelSize: Config.fontSize - 2
            wrapMode: Text.WordWrap
            width: parent.width
        }

        // --- Orbit view: focused view of the connected device ------------------
        Item {
            width: parent.width
            height: 460
            visible: root.viewMode === "orbit" && Bluetooth.powered

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
                            text: root.connectedDevice ? root.connectedDevice.name : "No device"
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
                        onClicked: Bluetooth.scanning ? Bluetooth.stopDiscovery() : Bluetooth.startDiscovery()
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
            visible: root.viewMode === "orbit" && Bluetooth.powered && root.devices.length === 0
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

            IconButton {
                width: 44
                height: 44
                active: true
                icon: "power_settings_new"
                iconSize: 18
                onClicked: Bridge.togglePowerMenu()
            }
        }

        // --- List view: Scan/Refresh + Pairing/Discoverable + My Devices / Nearby --
        // Flat text links, not cards — icon + accent-colored label, no
        // background at rest or on hover (just a slight dim), left-aligned.
        Row {
            width: parent.width
            visible: root.viewMode === "list" && Bluetooth.powered
            spacing: 20

            Item {
                id: scanLink
                width: scanLinkRow.implicitWidth
                height: scanLinkRow.implicitHeight
                opacity: scanLinkHover.hovered ? 0.7 : 1
                Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

                Row {
                    id: scanLinkRow
                    spacing: 6

                    MaterialIcon { icon: "search"; font.pixelSize: 15; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                    StyledText {
                        text: Bluetooth.scanning ? "Scanning…" : "Scan"
                        color: Colors.accent
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: scanLinkHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bluetooth.scanning ? Bluetooth.stopDiscovery() : Bluetooth.startDiscovery()
                }
            }

            Item {
                id: discoverableLink
                width: discoverableLinkRow.implicitWidth
                height: discoverableLinkRow.implicitHeight
                opacity: discoverableLinkHover.hovered ? 0.7 : 1
                Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

                Row {
                    id: discoverableLinkRow
                    spacing: 6

                    MaterialIcon { icon: "visibility"; font.pixelSize: 15; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                    StyledText {
                        text: Bluetooth.discoverable ? "Discoverable" : "Make Discoverable"
                        color: Colors.accent
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: discoverableLinkHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bluetooth.setDiscoverable(!Bluetooth.discoverable)
                }
            }
        }

        Column {
            width: parent.width
            visible: root.viewMode === "list" && Bluetooth.powered && myDevices.length > 0
            spacing: 4

            StyledText { text: "MY DEVICES"; opacity: 0.5; font.bold: true; font.pixelSize: Config.fontSize - 3 }

            Repeater {
                model: root.myDevices

                Column {
                    id: myRow
                    required property var modelData
                    readonly property bool expanded: root.expandedDevice === modelData.address
                    width: parent.width
                    spacing: 2

                    HoverRow {
                        width: parent.width
                        highlighted: myRow.modelData.connected
                        // Devices here are always paired, so this is just the
                        // connected/paired branch of Bluetooth's connect logic —
                        // the info button (below) handles expand/collapse instead.
                        onClicked: myRow.modelData.connected
                            ? Bluetooth.disconnectDevice(myRow.modelData.path)
                            : Bluetooth.connectDevice(myRow.modelData.path)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: infoBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            MaterialIcon { icon: root.iconFor(myRow.modelData); font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                spacing: 1
                                anchors.verticalCenter: parent.verticalCenter
                                StyledText { text: myRow.modelData.name; font.weight: Font.DemiBold }
                                StyledText {
                                    text: myRow.modelData.connected ? "Connected" : "Not Connected"
                                    opacity: 0.6
                                    font.pixelSize: Config.fontSize - 3
                                }
                            }
                        }

                        // Slides over the name/status text when expanded — matches
                        // the mockup's overlapping red "Forget" affordance.
                        PrimaryButton {
                            visible: myRow.expanded
                            anchors.right: infoBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 30
                            active: true
                            tint: Colors.danger
                            icon: "delete"
                            onClicked: Bluetooth.removeDevice(myRow.modelData.path)
                        }

                        IconButton {
                            id: infoBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "info"
                            iconSize: 15
                            onClicked: root.expandedDevice = myRow.expanded ? "" : myRow.modelData.address
                        }
                    }

                    Item {
                        visible: myRow.expanded
                        width: parent.width
                        height: 26

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
                            checked: myRow.modelData.trusted
                            onToggled: v => Bluetooth.setTrusted(myRow.modelData.path, v)
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            visible: root.viewMode === "list" && Bluetooth.powered && nearbyDevices.length > 0
            spacing: 4

            StyledText { text: "NEARBY"; opacity: 0.5; font.bold: true; font.pixelSize: Config.fontSize - 3 }

            Repeater {
                model: root.nearbyDevices

                HoverRow {
                    id: nearRow
                    required property var modelData
                    width: parent.width

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: connectBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        MaterialIcon { icon: root.iconFor(nearRow.modelData); font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: parent.width - 28
                            text: nearRow.modelData.name || nearRow.modelData.address
                        }
                    }

                    PrimaryButton {
                        id: connectBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 78
                        height: 28
                        enabled: !nearRow.modelData.pairing
                        active: true
                        text: nearRow.modelData.pairing ? "Pairing…" : "Connect"
                        onClicked: Bluetooth.pairDevice(nearRow.modelData.path)
                    }
                }
            }
        }

        StyledText {
            visible: root.viewMode === "list" && Bluetooth.powered && root.devices.length === 0
            text: "No devices found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        Item {
            width: switchRow.implicitWidth
            height: switchRow.implicitHeight
            visible: root.viewMode === "list" && Bluetooth.powered && !!root.connectedDevice

            Row {
                id: switchRow
                spacing: 6
                opacity: orbitLinkHover.containsMouse ? 1 : 0.7
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
