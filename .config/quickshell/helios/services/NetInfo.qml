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

    // One in-process read of /proc/net/dev per tick instead of spawning a
    // shell. Each row is "iface: rx_bytes <7 more rx fields> tx_bytes ...".
    function _pollBandwidth() {
        const ifaces = root._activeInterfaces();
        if (!ifaces.length) { root.rxRate = 0; root.txRate = 0; root._lastBytes = null; return; }
        netDev.reload();
        let rx = 0, tx = 0;
        for (const line of netDev.text().split("\n")) {
            const sep = line.indexOf(":");
            if (sep < 0 || !ifaces.includes(line.slice(0, sep).trim())) continue;
            const fields = line.slice(sep + 1).trim().split(/\s+/).map(Number);
            rx += fields[0];
            tx += fields[8];
        }
        const now = Date.now();
        if (root._lastBytes) {
            const dt = Math.max(0.5, (now - root._lastTime) / 1000);
            root.rxRate = Math.max(0, (rx - root._lastBytes.rx) / dt);
            root.txRate = Math.max(0, (tx - root._lastBytes.tx) / dt);
        }
        root._lastBytes = { rx, tx };
        root._lastTime = now;
    }

    property FileView netDev: FileView {
        path: "/proc/net/dev"
        blockLoading: true
    }

    Component.onCompleted: { root.refreshEthernet(); root.refreshVpn(); }
}
