pragma Singleton
import QtQuick
import Quickshell.Io

// Ethernet status, VPN connections, and bandwidth — the nmcli-backed
// counterparts to WifiNetworks.qml, which only covers wifi. Same
// terse-nmcli-output parsing style, kept in a separate service since it's a
// different device class, not different logic.
QtObject {
    id: root

    property bool ethernetConnected: false
    property string ethernetDevice: ""

    property var vpnConnections: []

    property real rxRate: 0
    property real txRate: 0

    function parseTerseLine(line) {
        const fields = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) {
                cur += line[i + 1];
                i++;
            } else if (line[i] === ":") {
                fields.push(cur);
                cur = "";
            } else {
                cur += line[i];
            }
        }
        fields.push(cur);
        return fields;
    }

    function refreshEthernet() {
        ethernetProc.running = false;
        ethernetProc.running = true;
    }

    property Process ethernetProc: Process {
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let connected = false;
                let device = "";
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    const f = root.parseTerseLine(line);
                    if (f[1] !== "ethernet") continue;
                    if (f[2] === "connected") { connected = true; device = f[0]; break; }
                }
                root.ethernetConnected = connected;
                root.ethernetDevice = device;
            }
        }
    }

    function refreshVpn() {
        vpnProc.running = false;
        vpnProc.running = true;
    }

    property Process vpnProc: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    const f = root.parseTerseLine(line);
                    if (f[1] !== "vpn" && f[1] !== "wireguard") continue;
                    list.push({ name: f[0], active: f[2] === "yes" });
                }
                root.vpnConnections = list;
            }
        }
    }

    function vpnUp(name) { root.runVpn(["nmcli", "connection", "up", "id", name]); }
    function vpnDown(name) { root.runVpn(["nmcli", "connection", "down", "id", name]); }

    function runVpn(cmd) {
        vpnActionProc.command = cmd;
        vpnActionProc.running = false;
        vpnActionProc.running = true;
    }

    property Process vpnActionProc: Process { onExited: root.refreshVpn() }

    // Bandwidth: sum rx/tx byte counters across whichever real interfaces
    // (wifi or ethernet) are currently connected, diffed against the last
    // sample. No new interface-discovery logic — reuses WifiNetworks' device
    // and ethernetDevice above.
    property var _lastBytes: null
    property double _lastTime: 0

    function _activeInterfaces() {
        const ifaces = [];
        if (WifiNetworks.wifiDevice && WifiNetworks.wifiDevice.name) ifaces.push(WifiNetworks.wifiDevice.name);
        if (root.ethernetConnected && root.ethernetDevice) ifaces.push(root.ethernetDevice);
        return ifaces;
    }

    property Timer bandwidthTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root._pollBandwidth()
    }

    function _pollBandwidth() {
        const ifaces = root._activeInterfaces();
        if (!ifaces.length) { root.rxRate = 0; root.txRate = 0; root._lastBytes = null; return; }
        bandwidthProc.command = ["sh", "-c",
            ifaces.map(i => `cat /sys/class/net/${i}/statistics/rx_bytes /sys/class/net/${i}/statistics/tx_bytes 2>/dev/null`).join("; ")];
        bandwidthProc.running = false;
        bandwidthProc.running = true;
    }

    property Process bandwidthProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const nums = text.split("\n").map(Number).filter(n => !isNaN(n));
                let rx = 0, tx = 0;
                for (let i = 0; i + 1 < nums.length; i += 2) { rx += nums[i]; tx += nums[i + 1]; }
                const now = Date.now();
                if (root._lastBytes) {
                    const dt = Math.max(0.5, (now - root._lastTime) / 1000);
                    root.rxRate = Math.max(0, (rx - root._lastBytes.rx) / dt);
                    root.txRate = Math.max(0, (tx - root._lastBytes.tx) / dt);
                }
                root._lastBytes = { rx, tx };
                root._lastTime = now;
            }
        }
    }

    Component.onCompleted: { root.refreshEthernet(); root.refreshVpn(); }
}
