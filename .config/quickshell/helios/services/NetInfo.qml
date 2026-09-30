pragma Singleton
import QtQuick
import Quickshell.Io

// Ethernet status and VPN connections — the nmcli-backed
// counterparts to WifiNetworks.qml, which only covers wifi. Same
// terse-nmcli-output parsing style, kept in a separate service since it's a
// different device class, not different logic.
QtObject {
    id: root

    property bool ethernetConnected: false
    property string ethernetDevice: ""

    property var vpnConnections: []

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

    Component.onCompleted: { root.refreshEthernet(); root.refreshVpn(); }
}
