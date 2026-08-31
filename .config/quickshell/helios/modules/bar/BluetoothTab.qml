import QtQuick
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var devices: Bluetooth.devices
    readonly property var connectedDevice: root.devices.find(d => d.connected) || null
    readonly property var audioProfile: root.connectedDevice
        ? BluetoothAudio.profileForAddress(root.connectedDevice.address) : null
    readonly property string audioProfileLabel: root.audioProfile
        ? [root.audioProfile.codec, root.audioProfile.profile].filter(part => !!part).join(" · ")
        : "—"
    // Trusted, not just Paired: some devices (confirmed for the Soundcore
    // R60i NC) never persist a real bond — BlueZ reports Paired: false the
    // moment they disconnect, even though Trusted (the actual "this is my
    // device" flag) survives. Keying off paired alone made such a device
    // vanish into "Nearby" every time it disconnected.
    readonly property var myDevices: root.devices.filter(d => d.paired || d.trusted)
    readonly property var nearbyDevices: root.devices.filter(d => !d.paired && !d.trusted)

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
        OrbitPanel {
            id: orbitView
            visible: root.viewMode === "orbit" && Bluetooth.powered
            active: root.viewMode === "orbit" && Bluetooth.powered

            centerIcon: "headset"
            centerTitle: root.connectedDevice ? root.connectedDevice.name : "No device"
            centerSubtitle: root.connectedDevice ? "Connected" : "Not connected"

            scanLabel: Bluetooth.scanning ? "Scanning…" : "Scan Devices"
            onScanClicked: Bluetooth.scanning ? Bluetooth.stopDiscovery() : Bluetooth.startDiscovery()
            onSwitchViewClicked: root.viewMode = "list"

            infoCards: [
                {
                    angle: 180, width: 180, icon: "dns", monospace: true,
                    value: root.connectedDevice ? root.connectedDevice.address : "—",
                    label: "MAC Address"
                },
                {
                    angle: 0, width: 180, icon: "battery_full", monospace: false,
                    value: root.connectedDevice && root.connectedDevice.batteryAvailable
                        ? Math.round(root.connectedDevice.battery * 100) + "%" : "—",
                    label: "Battery"
                },
                {
                    angle: 90, width: 190, icon: "graphic_eq", monospace: false,
                    value: root.audioProfileLabel,
                    label: "Audio Profile"
                }
            ]
        }

        StyledText {
            visible: root.viewMode === "orbit" && Bluetooth.powered && root.devices.length === 0
            text: "No devices found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        // --- Bottom bar: Wi-Fi / Bluetooth switch + power -----------------------
        IslandModeSwitcher {
            width: parent.width
            visible: root.viewMode === "orbit"
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
                        // Trusted-but-unpaired devices (see myDevices above)
                        // need Pair(), not Connect() — the info button
                        // (below) handles expand/collapse instead.
                        onClicked: {
                            if (myRow.modelData.connected) Bluetooth.disconnectDevice(myRow.modelData.path);
                            else if (myRow.modelData.paired) Bluetooth.connectDevice(myRow.modelData.path);
                            else Bluetooth.pairDevice(myRow.modelData.path);
                        }

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
