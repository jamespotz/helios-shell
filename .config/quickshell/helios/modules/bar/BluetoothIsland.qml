import QtQuick
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var bluetooth: Bluetooth.state
    readonly property var devices: root.bluetooth.devices
    readonly property var connectedDevice: root.devices.find(d => d.connected) || null
    readonly property var audioProfile: root.connectedDevice ? root.connectedDevice.audio : null
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

    function typeLabel(dev) {
        const raw = (dev.icon || "").toLowerCase();
        if (raw.includes("headset") || raw.includes("headphone")) return "Audio device";
        if (raw.includes("phone")) return "Phone";
        if (raw.includes("keyboard")) return "Keyboard";
        if (raw.includes("mouse")) return "Mouse";
        if (raw.includes("audio") || raw.includes("speaker")) return "Audio device";
        if (raw.includes("watch")) return "Wearable";
        return dev.name ? "Available" : "Unnamed device";
    }

    // Which device (by address) has its auto-connect switch expanded open in
    // the list. Pressing a device's row toggles this rather than showing
    // it always, to keep the list compact.
    property string expandedDevice: ""

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    Component.onCompleted: Bluetooth.setActive(true)
    Component.onDestruction: Bluetooth.setActive(false)

    Column {
        id: col
        width: parent.width
        spacing: 14

        Item {
            width: parent.width
            height: 48

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: "Bluetooth"
                    font.weight: Font.DemiBold
                    font.pixelSize: Config.fontSize + 2
                }
                Row {
                    spacing: 4

                    StyledText {
                        text: !root.bluetooth.available ? "No adapter" : (root.bluetooth.powered ? "On" : "Off")
                        opacity: 0.6
                        font.pixelSize: Config.fontSize - 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    LoadingSpinner {
                        visible: root.bluetooth.scanning
                        active: root.bluetooth.scanning
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.bluetooth.powered
                enabled: root.bluetooth.available
                onToggled: v => Bluetooth.setPowered(v)
            }
        }

        StyledText {
            visible: root.bluetooth.lastError.length > 0
            text: root.bluetooth.lastError
            color: Colors.danger
            font.pixelSize: Config.fontSize - 2
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Item {
            width: parent.width
            height: profileSwitch.implicitHeight
            visible: root.bluetooth.powered && !!root.audioProfile

            SegmentedControl {
                id: profileSwitch
                width: 180
                anchors.left: parent.left
                model: [
                    { value: "music", label: "Audio", icon: "" },
                    { value: "call", label: "Calls", icon: "" }
                ]
                currentValue: root.audioProfile ? root.audioProfile.category : null
                onActivated: value => Bluetooth.setAudioProfile(root.connectedDevice.id, value)
            }
        }

        // Scan/Refresh + Pairing/Discoverable + My Devices / Nearby
        // Flat text links, not cards — icon + accent-colored label, no
        // background at rest or on hover (just a slight dim), left-aligned.
        Row {
            width: parent.width
            visible: root.bluetooth.powered
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

                    LoadingSpinner {
                        visible: root.bluetooth.scanning
                        active: root.bluetooth.scanning
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MaterialIcon {
                        visible: !root.bluetooth.scanning
                        icon: "search"; font.pixelSize: 15; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: "Scan"
                        color: Colors.accent
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: scanLinkHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bluetooth.setScanning(!root.bluetooth.scanning)
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
                        text: root.bluetooth.discoverable ? "Discoverable" : "Make Discoverable"
                        color: Colors.accent
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: discoverableLinkHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bluetooth.setDiscoverable(!root.bluetooth.discoverable)
                }
            }
        }

        Column {
            width: parent.width
            visible: root.bluetooth.powered && myDevices.length > 0
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
                        // Trusted survives the R60i's Paired:false-on-disconnect
                        // quirk (see myDevices above); Pair() only makes sense
                        // for devices with neither flag set.
                        onClicked: {
                            if (myRow.modelData.connected) Bluetooth.disconnect(myRow.modelData.id);
                            else if (myRow.modelData.paired || myRow.modelData.trusted) Bluetooth.connect(myRow.modelData.id);
                            else Bluetooth.pair(myRow.modelData.id);
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: !myRow.modelData.connected && !myRow.expanded ? connectButton.left : infoBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            MaterialIcon { icon: root.iconFor(myRow.modelData); font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                spacing: 1
                                anchors.verticalCenter: parent.verticalCenter
                                StyledText { text: myRow.modelData.name; font.weight: Font.DemiBold }
                                Row {
                                    spacing: 4
                                    Rectangle {
                                        visible: myRow.modelData.connected
                                        width: 7
                                        height: 7
                                        radius: 4
                                        color: Colors.success
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    StyledText {
                                        text: myRow.modelData.connected ? "Connected" : "Not Connected"
                                        opacity: 0.6
                                        font.pixelSize: Config.fontSize - 3
                                    }
                                    // Device continuity: battery for whatever this
                                    // device is (mouse, keyboard, headset, controller,
                                    // phone) — BlueZ's Battery1 interface generalizes
                                    // across device types, so one badge covers all of
                                    // them with no per-category logic.
                                    Row {
                                        visible: myRow.modelData.connected && myRow.modelData.batteryAvailable
                                        spacing: 2
                                        StyledText { text: "·"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                                        MaterialIcon {
                                            icon: "battery_full"
                                            font.pixelSize: 11
                                            color: Math.round(myRow.modelData.battery * 100) <= Bluetooth.lowBatteryThreshold ? Colors.danger : Colors.subtext
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: Math.round(myRow.modelData.battery * 100) + "%"
                                            color: Math.round(myRow.modelData.battery * 100) <= Bluetooth.lowBatteryThreshold ? Colors.danger : Colors.subtext
                                            opacity: 0.9
                                            font.pixelSize: Config.fontSize - 3
                                        }
                                    }
                                }
                            }
                        }

                        PrimaryButton {
                            id: connectButton
                            visible: !myRow.modelData.connected && !myRow.expanded
                            anchors.right: infoBtn.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 76
                            height: 28
                            text: "Connect"
                            onClicked: Bluetooth.connect(myRow.modelData.id)
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
                            onClicked: Bluetooth.forget(myRow.modelData.id)
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
                            onToggled: v => Bluetooth.setAutoConnect(myRow.modelData.id, v)
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            visible: root.bluetooth.powered && nearbyDevices.length > 0
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
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 28

                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: nearRow.modelData.name || nearRow.modelData.address
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.typeLabel(nearRow.modelData)
                                opacity: 0.6
                                font.pixelSize: Config.fontSize - 3
                            }
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
                        onClicked: Bluetooth.pair(nearRow.modelData.id)
                    }
                }
            }
        }

        StyledText {
            visible: root.bluetooth.powered && root.devices.length === 0
            text: "No devices found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }
    }
}
