import QtQuick
import Quickshell.Networking
import "../../services"
import "../../components"

// Thin view — all scan/connect/forget state and nmcli calls live in
// services/WifiNetworks.qml (cached across opens, see that file's header
// comment) so this only wires the singleton up to widgets.
Item {
    id: root

    readonly property var wn: WifiNetworks
    readonly property var connectedNetwork: root.wn.networks.find(n => n.connected) || null

    // "orbit" is the focused single-network view matching Bluetooth's; "list"
    // is the scannable flat network list, still the better view when nothing
    // is connected yet.
    property string viewMode: root.connectedNetwork ? "orbit" : "list"

    property bool addNetworkOpen: false
    property string addSecurity: "wpa"
    property bool addPasswordVisible: false

    // Closing the tab with a password prompt open shouldn't leave it (and
    // any stale "Incorrect password" error) expanded the next time this
    // tab opens — expandedNetwork/connectError live on the shared singleton
    // now so the network list itself can be cached, but per-open UI state
    // like this shouldn't persist with it.
    Component.onDestruction: {
        wn.expandedNetwork = "";
        wn.connectError = "";
    }

    implicitWidth: root.viewMode === "orbit" ? 720 : 320
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 22

            MaterialIcon {
                id: wifiHeaderIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: Networking.wifiEnabled ? "wifi" : "wifi_off"
            }

            StyledText {
                anchors.left: wifiHeaderIcon.right
                anchors.leftMargin: 10
                anchors.right: wifiToggle.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: !Networking.wifiHardwareEnabled ? "Disabled by hardware switch"
                    : Networking.wifiEnabled ? (root.wn.scanning ? "Scanning…" : "On") : "Off"
            }

            IconButton {
                anchors.right: wifiToggle.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                icon: "refresh"
                visible: Networking.wifiEnabled
                onClicked: root.wn.scan()
            }

            Toggle {
                id: wifiToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Networking.wifiEnabled
                enabled: Networking.wifiHardwareEnabled
                onToggled: v => Networking.wifiEnabled = v
            }
        }

        // --- Orbit view: focused view of the connected network -----------------
        Item {
            id: orbitView
            width: parent.width
            height: 460
            visible: root.viewMode === "orbit" && Networking.wifiEnabled

            Item {
                id: orbitCenter
                anchors.centerIn: parent
                width: 1
                height: 1

                // Drives the satellite cards around the outer ring — cards
                // travel the circle but stay upright (position-only, no
                // rotation on the cards themselves) so their text stays
                // readable throughout. Paused when the view isn't visible.
                property real orbitAngle: 0
                NumberAnimation on orbitAngle {
                    running: orbitView.visible
                    from: 0
                    to: 360
                    duration: 60000
                    loops: Animation.Infinite
                }

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
                            icon: "wifi"
                            font.pixelSize: 40
                            color: Colors.secondaryText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: root.connectedNetwork ? root.connectedNetwork.ssid : "No network"
                            color: Colors.secondaryText
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: root.connectedNetwork ? "Connected" : "Not connected"
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
                    readonly property real orbitBaseAngle: -90
                    x: 190 * Math.cos((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - width / 2
                    y: 190 * Math.sin((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - height / 2

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        MaterialIcon { icon: "search"; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 2
                            StyledText { text: "Scan Networks"; font.bold: true; font.pixelSize: Config.fontSize - 1 }
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
                        onClicked: root.wn.scan()
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
                    readonly property real orbitBaseAngle: 180
                    x: 190 * Math.cos((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - width / 2
                    y: 190 * Math.sin((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - height / 2

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        MaterialIcon { icon: "dns"; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 2
                            StyledText {
                                text: root.wn.wifiDevice && root.wn.wifiDevice.address ? root.wn.wifiDevice.address : "—"
                                font.bold: true
                                font.family: Config.monoFontFamily
                                font.pixelSize: Config.fontSize - 2
                            }
                            StyledText { text: "IP Address"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                        }
                    }
                }

                Rectangle {
                    width: 180
                    height: 56
                    radius: Colors.radiusLarge
                    color: Colors.surfaceHigh
                    readonly property real orbitBaseAngle: 0
                    x: 190 * Math.cos((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - width / 2
                    y: 190 * Math.sin((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - height / 2

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: !root.connectedNetwork ? "wifi_off"
                                : root.connectedNetwork.signal > 70 ? "wifi"
                                : root.connectedNetwork.signal > 40 ? "wifi_2_bar" : "wifi_1_bar"
                        }
                        Column {
                            spacing: 2
                            StyledText {
                                text: root.connectedNetwork ? root.connectedNetwork.signal + "%" : "—"
                                font.bold: true
                                font.pixelSize: Config.fontSize - 1
                            }
                            StyledText { text: "Signal"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                        }
                    }
                }

                Rectangle {
                    width: 190
                    height: 56
                    radius: Colors.radiusLarge
                    color: Colors.surfaceHigh
                    readonly property real orbitBaseAngle: 90
                    x: 190 * Math.cos((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - width / 2
                    y: 190 * Math.sin((orbitCenter.orbitAngle + orbitBaseAngle) * Math.PI / 180) - height / 2

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        MaterialIcon {
                            icon: root.connectedNetwork && root.connectedNetwork.secured ? "lock" : "lock_open"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            spacing: 2
                            StyledText {
                                text: !root.connectedNetwork ? "—" : (root.connectedNetwork.secured ? root.connectedNetwork.security : "Open")
                                font.bold: true
                                font.pixelSize: Config.fontSize - 1
                            }
                            StyledText { text: "Security"; opacity: 0.6; font.pixelSize: Config.fontSize - 3 }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: root.viewMode === "orbit" && Networking.wifiEnabled && root.wn.loaded && root.wn.networks.length === 0
            text: "No networks found"
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

        StyledText {
            visible: root.viewMode === "list" && Networking.wifiEnabled && root.wn.loaded && root.wn.networks.length === 0
            text: "No networks found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        ListView {
            id: networkList
            width: parent.width
            visible: root.viewMode === "list" && Networking.wifiEnabled
            // contentHeight (not a row-count*46 estimate) so an expanded
            // network's password box/error text — which the estimate never
            // accounted for — isn't clipped off by an undersized viewport.
            height: visible ? Math.min(260, contentHeight) : 0
            clip: true
            spacing: 2
            model: root.wn.networks
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: networkList }

            delegate: Column {
                id: netRow
                required property var modelData
                required property int index

                readonly property bool known: root.wn.isKnown(modelData.ssid)
                readonly property bool needsPassword: root.wn.expandedNetwork === modelData.ssid
                property bool passwordVisible: false

                width: networkList.width
                spacing: 4

                HoverRow {
                    id: card
                    width: parent.width
                    highlighted: netRow.modelData.connected
                    onClicked: root.wn.activate(netRow.modelData)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: netRow.modelData.signal > 70 ? "wifi"
                                : netRow.modelData.signal > 40 ? "wifi_2_bar" : "wifi_1_bar"
                            font.pixelSize: 16
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 16 - 16 - (netRow.modelData.secured ? 16 : 0) - (netRow.known ? 22 : 0) - 16 - 24
                            elide: Text.ElideRight
                            text: netRow.modelData.ssid
                        }

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: netRow.modelData.secured
                            icon: "lock"
                            font.pixelSize: 14
                        }

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: netRow.modelData.connected
                            icon: "check"
                            font.pixelSize: 16
                        }

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: netRow.known
                            icon: "delete"
                            font.pixelSize: 14
                            // Only surfaces on hover — an always-on delete icon
                            // next to every known network reads as clutter;
                            // Apple's own Wi-Fi menu keeps per-row actions
                            // hidden until you're actually pointed at the row.
                            opacity: card.hovering ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -2
                                cursorShape: Qt.PointingHandCursor
                                enabled: card.hovering
                                onClicked: root.wn.forget(netRow.modelData.ssid)
                            }
                        }
                    }
                }

                StyledText {
                    visible: netRow.needsPassword && root.wn.connectError.length > 0
                    text: root.wn.connectError
                    color: Colors.danger
                    font.pixelSize: Config.fontSize - 3
                    leftPadding: 4
                }

                Column {
                    width: parent.width
                    visible: netRow.needsPassword
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 6

                        Rectangle {
                            width: parent.width - 32 - 6
                            height: 32
                            radius: height / 2
                            color: Colors.surfaceHigh

                            TextInput {
                                id: pwInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 32
                                color: Colors.text
                                font.family: Config.fontFamily
                                font.pixelSize: Config.fontSize
                                echoMode: netRow.passwordVisible ? TextInput.Normal : TextInput.Password
                                clip: true
                                focus: netRow.needsPassword
                                Keys.onReturnPressed: root.wn.submitPassword(netRow.modelData.ssid, pwInput.text)
                            }

                            IconButton {
                                anchors.right: parent.right
                                anchors.rightMargin: 1
                                anchors.verticalCenter: parent.verticalCenter
                                icon: netRow.passwordVisible ? "visibility_off" : "visibility"
                                iconSize: 15
                                onClicked: netRow.passwordVisible = !netRow.passwordVisible
                            }
                        }

                        IconButton {
                            icon: "close"
                            onClicked: root.wn.expandedNetwork = ""
                        }
                    }

                    PrimaryButton {
                        width: parent.width
                        height: 32
                        active: true
                        tint: Colors.secondary
                        tintText: Colors.secondaryText
                        text: "Join"
                        onClicked: root.wn.submitPassword(netRow.modelData.ssid, pwInput.text)
                    }
                }
            }
        }

        // --- Manually add a (usually hidden) network ------------------------

        HoverRow {
            width: parent.width
            height: 36
            highlighted: root.addNetworkOpen
            visible: root.viewMode === "list" && Networking.wifiEnabled && !!root.wn.wifiDevice
            onClicked: root.addNetworkOpen = !root.addNetworkOpen

            Row {
                anchors.centerIn: parent
                spacing: 6
                MaterialIcon {
                    icon: root.addNetworkOpen ? "close" : "add"
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.addNetworkOpen ? "Close" : "Add network manually"
                    font.pixelSize: Config.fontSize - 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8
            visible: root.viewMode === "list" && root.addNetworkOpen && Networking.wifiEnabled && !!root.wn.wifiDevice

            Rectangle {
                width: parent.width
                height: 32
                radius: height / 2
                color: Colors.surfaceHigh

                TextInput {
                    id: addSsidInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    color: Colors.text
                    font.family: Config.fontFamily
                    font.pixelSize: Config.fontSize
                    clip: true

                    StyledText {
                        visible: addSsidInput.text.length === 0
                        text: "Network name (SSID)"
                        opacity: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            StyledText {
                text: "Security"
                opacity: 0.6
                font.pixelSize: Config.fontSize - 2
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.wn.securityOptions

                    Chip {
                        required property var modelData
                        active: root.addSecurity === modelData.key
                        tint: Colors.secondary
                        tintText: Colors.secondaryText
                        text: modelData.label
                        onClicked: root.addSecurity = modelData.key
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: height / 2
                color: Colors.surfaceHigh
                visible: root.addSecurity !== "open"

                TextInput {
                    id: addPwInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 32
                    color: Colors.text
                    font.family: Config.fontFamily
                    font.pixelSize: Config.fontSize
                    echoMode: root.addPasswordVisible ? TextInput.Normal : TextInput.Password
                    clip: true
                    Keys.onReturnPressed: root.submitAddNetwork()

                    StyledText {
                        visible: addPwInput.text.length === 0
                        text: "Password"
                        opacity: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.addPasswordVisible ? "visibility_off" : "visibility"
                    iconSize: 15
                    onClicked: root.addPasswordVisible = !root.addPasswordVisible
                }
            }

            PrimaryButton {
                width: parent.width
                height: 32
                active: true
                tint: Colors.secondary
                tintText: Colors.secondaryText
                text: "Join"
                onClicked: root.submitAddNetwork()
            }
        }
    }

    function submitAddNetwork() {
        const ssid = addSsidInput.text.trim();
        if (!ssid || !root.wn.wifiDevice) return;
        root.wn.addNetwork(ssid, root.wn.wifiDevice.name, addPwInput.text, root.addSecurity);
        addSsidInput.text = "";
        addPwInput.text = "";
        addNetworkOpen = false;
        addPasswordVisible = false;
    }
}
