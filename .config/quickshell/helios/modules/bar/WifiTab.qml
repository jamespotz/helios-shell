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
    property bool addNetworkOpen: false
    property string addSecurity: "wpa"

    // Closing the tab with a password prompt open shouldn't leave it (and
    // any stale "Incorrect password" error) expanded the next time this
    // tab opens — expandedNetwork/connectError live on the shared singleton
    // now so the network list itself can be cached, but per-open UI state
    // like this shouldn't persist with it.
    Component.onDestruction: {
        wn.expandedNetwork = "";
        wn.connectError = "";
    }

    implicitWidth: 320
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

        StyledText {
            visible: Networking.wifiEnabled && root.wn.loaded && root.wn.networks.length === 0
            text: "No networks found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        ListView {
            id: networkList
            width: parent.width - 8
            visible: Networking.wifiEnabled
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

                width: networkList.width
                spacing: 4

                HoverRow {
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

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -2
                                cursorShape: Qt.PointingHandCursor
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

                Row {
                    width: parent.width
                    visible: netRow.needsPassword
                    spacing: 6

                    Rectangle {
                        width: parent.width - 32 - 32 - 12
                        height: 32
                        radius: Colors.radiusSmall
                        color: Colors.surfaceHigh

                        TextInput {
                            id: pwInput
                            anchors.fill: parent
                            anchors.margins: 8
                            color: Colors.text
                            font.family: Config.fontFamily
                            font.pixelSize: Config.fontSize
                            echoMode: TextInput.Password
                            clip: true
                            focus: netRow.needsPassword
                            Keys.onReturnPressed: root.wn.submitPassword(netRow.modelData.ssid, pwInput.text)
                        }
                    }

                    IconButton {
                        icon: "arrow_forward"
                        onClicked: root.wn.submitPassword(netRow.modelData.ssid, pwInput.text)
                    }

                    IconButton {
                        icon: "close"
                        onClicked: root.wn.expandedNetwork = ""
                    }
                }
            }
        }

        // --- Manually add a (usually hidden) network ------------------------

        HoverRow {
            width: parent.width
            height: 36
            highlighted: root.addNetworkOpen
            visible: Networking.wifiEnabled && !!root.wn.wifiDevice
            border.width: 1
            border.color: Colors.overlay
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
            visible: root.addNetworkOpen && Networking.wifiEnabled && !!root.wn.wifiDevice

            Rectangle {
                width: parent.width
                height: 32
                radius: Colors.radiusSmall
                color: Colors.surfaceHigh

                TextInput {
                    id: addSsidInput
                    anchors.fill: parent
                    anchors.margins: 8
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

                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool active: root.addSecurity === modelData.key

                        width: label.implicitWidth + 20
                        height: 28
                        radius: Colors.radiusSmall
                        color: active ? Colors.secondary : Colors.surfaceHigh
                        Behavior on color { ColorAnimation { duration: Config.animFast } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Colors.surfaceHigh
                            opacity: chipHover.hovered && !chip.active ? 0.25 : 0
                        }

                        HoverHandler { id: chipHover }

                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Config.fontSize - 2
                            color: chip.active ? Colors.secondaryText : Colors.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.addSecurity = modelData.key
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6
                visible: root.addSecurity !== "open"

                Rectangle {
                    width: parent.width - 38 - 6
                    height: 32
                    radius: Colors.radiusSmall
                    color: Colors.surfaceHigh

                    TextInput {
                        id: addPwInput
                        anchors.fill: parent
                        anchors.margins: 8
                        color: Colors.text
                        font.family: Config.fontFamily
                        font.pixelSize: Config.fontSize
                        echoMode: TextInput.Password
                        clip: true
                        Keys.onReturnPressed: root.submitAddNetwork()

                        StyledText {
                            visible: addPwInput.text.length === 0
                            text: "Password"
                            opacity: 0.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                IconButton {
                    icon: "arrow_forward"
                    onClicked: root.submitAddNetwork()
                }
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: Colors.radiusSmall
                color: Colors.secondary
                visible: root.addSecurity === "open"

                StyledText {
                    anchors.centerIn: parent
                    text: "Connect"
                    color: Colors.secondaryText
                    font.bold: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.surfaceHigh
                    opacity: connectBtnHover.hovered ? 0.2 : 0
                }

                HoverHandler { id: connectBtnHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitAddNetwork()
                }
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
    }
}
