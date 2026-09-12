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
    readonly property var displayNetworks: {
        const result = root.wn.networks.slice();
        for (const name of root.wn.knownNames) {
            if (!result.some(network => network.ssid === name)) {
                result.push({
                    ssid: name,
                    signal: 0,
                    security: "Saved",
                    secured: true,
                    connected: false,
                    savedOnly: true
                });
            }
        }
        return result;
    }
    readonly property var connectedNetworks: root.displayNetworks.filter(network => network.connected)
    readonly property var myNetworks: root.displayNetworks.filter(network => !network.connected && root.wn.isKnown(network.ssid))
    readonly property var otherNetworks: root.displayNetworks.filter(network => !network.connected && !root.wn.isKnown(network.ssid))

    property bool addNetworkOpen: false
    property string addSecurity: "wpa"
    property bool addPasswordVisible: false
    property string expandedInfoNetwork: ""

    // Closing the tab with a password prompt open shouldn't leave it (and
    // any stale "Incorrect password" error) expanded the next time this
    // tab opens — expandedNetwork/connectError live on the shared singleton
    // now so the network list itself can be cached, but per-open UI state
    // like this shouldn't persist with it.
    Component.onDestruction: {
        wn.expandedNetwork = "";
        wn.connectError = "";
    }

    // The singleton's own startup scan keeps the cache warm so this view
    // never blocks on a fresh list, but a rescan on every open still keeps
    // it current — cheap since scan() is just an nmcli rescan trigger, not
    // a blocking call.
    Component.onCompleted: {
        if (Networking.wifiEnabled && !wn.scanning) wn.scan();
    }

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    Component {
        id: networkDelegate

        Column {
            id: netRow
            required property var modelData
            readonly property bool known: root.wn.isKnown(modelData.ssid)
            readonly property bool needsPassword: root.wn.expandedNetwork === modelData.ssid
            property bool passwordVisible: false
            width: parent ? parent.width : 0
            spacing: 4

            HoverRow {
                id: card
                width: parent.width
                highlighted: netRow.modelData.connected
                onClicked: root.wn.activate(netRow.modelData)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 8

                    MaterialIcon {
                        visible: netRow.modelData.connected
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "check"
                        color: Colors.accent
                        font.pixelSize: 16
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (netRow.modelData.connected ? 24 : 0)
                            - (netRow.modelData.secured ? 20 : 0) - 44
                        elide: Text.ElideRight
                        text: netRow.modelData.ssid
                    }

                    MaterialIcon {
                        visible: netRow.modelData.secured
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "lock"
                        opacity: 0.7
                        font.pixelSize: 13
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: netRow.modelData.savedOnly ? "history"
                            : netRow.modelData.signal > 70 ? "wifi"
                            : netRow.modelData.signal > 40 ? "wifi_2_bar" : "wifi_1_bar"
                        opacity: 0.7
                        font.pixelSize: 15
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        icon: "info"
                        iconSize: 16
                        iconColor: Colors.accent
                        onClicked: root.expandedInfoNetwork = root.expandedInfoNetwork === netRow.modelData.ssid
                            ? "" : netRow.modelData.ssid
                    }
                }
            }

            Row {
                visible: root.expandedInfoNetwork === netRow.modelData.ssid
                width: parent.width
                height: visible ? 34 : 0
                leftPadding: 12
                rightPadding: 8
                spacing: 8

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (netRow.known ? forgetButton.width + 28 : 20)
                    elide: Text.ElideRight
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 3
                    text: netRow.modelData.savedOnly ? "Saved network"
                        : netRow.modelData.signal + "%  ·  " + (netRow.modelData.secured ? netRow.modelData.security : "Open")
                }

                PrimaryButton {
                    id: forgetButton
                    visible: netRow.known
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 26
                    tint: Colors.danger
                    tintText: Colors.errorText
                    text: "Forget"
                    onClicked: {
                        root.expandedInfoNetwork = "";
                        root.wn.forget(netRow.modelData.ssid);
                    }
                }
            }

            StyledText {
                visible: netRow.needsPassword && root.wn.connectError.length > 0
                text: root.wn.connectError
                color: Colors.danger
                font.pixelSize: Config.fontSize - 3
                leftPadding: 12
            }

            Column {
                width: parent.width
                visible: netRow.needsPassword
                spacing: 8
                leftPadding: 8
                rightPadding: 8
                bottomPadding: 8

                Row {
                    width: parent.width - 16
                    spacing: 6

                    Rectangle {
                        width: parent.width - 38
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

                    IconButton { icon: "close"; onClicked: root.wn.expandedNetwork = "" }
                }

                PrimaryButton {
                    width: parent.width - 16
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

                Row {
                    spacing: 8
                    MaterialIcon {
                        icon: Networking.wifiEnabled ? "wifi" : "wifi_off"
                        font.pixelSize: 18
                        color: Colors.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: "Wi-Fi"
                        font.weight: Font.DemiBold
                        font.pixelSize: Config.fontSize + 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 4

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: !Networking.wifiHardwareEnabled ? "Disabled by hardware switch"
                            : Networking.wifiEnabled ? "On" : "Off"
                        opacity: 0.6
                        font.pixelSize: Config.fontSize - 2
                    }
                    LoadingSpinner {
                        visible: root.wn.scanning
                        active: root.wn.scanning
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
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

        Item {
            id: scanLink
            visible: Networking.wifiEnabled
            width: scanLinkRow.implicitWidth
            height: visible ? scanLinkRow.implicitHeight : 0
            opacity: scanLinkHover.hovered ? 0.7 : 1
            Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

            Row {
                id: scanLinkRow
                spacing: 6

                LoadingSpinner {
                    visible: root.wn.scanning
                    active: root.wn.scanning
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                MaterialIcon {
                    visible: !root.wn.scanning
                    icon: "search"
                    font.pixelSize: 15
                    color: Colors.accent
                    anchors.verticalCenter: parent.verticalCenter
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
                enabled: !root.wn.scanning
                cursorShape: Qt.PointingHandCursor
                onClicked: root.wn.scan()
            }
        }

        StyledText {
            visible: Networking.wifiEnabled && root.wn.loaded && root.displayNetworks.length === 0
            text: "No networks found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        Item {
            id: networkListWrap
            width: parent.width
            visible: Networking.wifiEnabled
            height: visible ? Math.min(300, networkGroups.implicitHeight) : 0

            Flickable {
                id: networkList
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: networkGroups.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: networkGroups
                    width: networkList.width
                    spacing: 12

                    Repeater {
                        model: root.connectedNetworks
                        delegate: networkDelegate
                    }

                    Column {
                        width: parent.width
                        visible: root.myNetworks.length > 0
                        spacing: 5

                        StyledText {
                            text: "MY NETWORKS"
                            opacity: 0.5
                            font.bold: true
                            font.pixelSize: Config.fontSize - 3
                            leftPadding: 0
                        }

                        Column {
                            id: myNetworkRows
                            width: parent.width
                            Repeater { model: root.myNetworks; delegate: networkDelegate }
                        }
                    }

                    Column {
                        width: parent.width
                        visible: root.otherNetworks.length > 0
                        spacing: 5

                        StyledText {
                            text: "OTHER NETWORKS"
                            opacity: 0.5
                            font.bold: true
                            font.pixelSize: Config.fontSize - 3
                            leftPadding: 0
                        }

                        Column {
                            id: otherNetworkRows
                            width: parent.width
                            Repeater { model: root.otherNetworks; delegate: networkDelegate }
                        }
                    }
                }
            }

            ScrollIndicator { target: networkList }
        }

        // --- Manually add a (usually hidden) network ------------------------

        HoverRow {
            width: parent.width
            height: 36
            highlighted: root.addNetworkOpen
            visible: Networking.wifiEnabled && !!root.wn.wifiDevice
            onClicked: root.addNetworkOpen = !root.addNetworkOpen

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                MaterialIcon {
                    icon: root.addNetworkOpen ? "close" : "add"
                    font.pixelSize: 16
                    color: Colors.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.addNetworkOpen ? "Close" : "Add network manually"
                    font.pixelSize: Config.fontSize - 1
                    color: Colors.accent
                    font.weight: Font.Medium
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
