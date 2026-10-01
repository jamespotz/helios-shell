import QtQuick
import Quickshell.Io
import "../../../services"
import "../../../components"

MonitorCard {
    id: root

    readonly property var stats: SystemStats.state
    readonly property var network: root.stats.network
    readonly property var speedTest: SystemStats.speedTest
    // Connected Wi-Fi network, from NetworkManager via Quickshell.Networking —
    // only when that Wi-Fi device is the interface whose IP is shown.
    readonly property string ssid: {
        const device = WifiNetworks.wifiDevice;
        if (!device || device.name !== root.network.iface) return "";
        const connected = device.networks.values.find(network => network.connected);
        return connected ? connected.name : "";
    }

    title: "Network"
    label: root.ssid || root.network.iface || "Not connected"
    icon: root.network.iface_type === "wifi" ? "wifi" : root.network.iface ? "lan" : "wifi_off"
    footerText: !root.speedTest ? ""
        : root.speedTest.running ? "Testing…"
        : root.speedTest.error ? root.speedTest.error
        : "↓ " + root.speedTest.downMbps.toFixed(0) + " Mbps  ↑ " + root.speedTest.upMbps.toFixed(0) + " Mbps"
    actionText: "Test Speed"
    actionVisible: SystemStats.speedTestTool.length > 0
    actionEnabled: !(root.speedTest && root.speedTest.running)
    onActionTriggered: SystemStats.runSpeedTest()

    Item {
        width: parent.width
        height: copyButton.height

        StyledText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Local" + (root.network.iface ? " · " + root.network.iface : "")
            opacity: 0.7
            font.pixelSize: Config.fontSize - 2
        }
        StyledText {
            anchors.right: copyButton.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.network.local_ip || "—"
            font.pixelSize: Config.fontSize - 2
            font.family: Config.monoFontFamily
        }
        IconButton {
            id: copyButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 24
            implicitHeight: 24
            icon: "content_copy"
            iconSize: 14
            label: "Copy local IP"
            enabled: !!root.network.local_ip
            onClicked: {
                copyProc.command = ["sh", "-c", "printf '%s' \"$0\" | wl-copy", root.network.local_ip];
                copyProc.running = false;
                copyProc.running = true;
            }
        }
    }

    RateRow {
        downBytesPerSec: root.stats.networkRate.receivedKBs * 1024
        upBytesPerSec: root.stats.networkRate.sentKBs * 1024
    }

    LineGraph {
        width: parent.width
        height: 40
        values: root.stats.history.netReceived
        secondaryValues: root.stats.history.netSent
        minScale: 64
    }

    Process { id: copyProc }
}
