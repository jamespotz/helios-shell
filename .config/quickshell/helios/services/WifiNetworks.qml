pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Networking

// Wifi scan state + nmcli actions, lifted out of WifiTab.qml so the list is
// cached across the tab closing/reopening (it used to re-run `nmcli device
// wifi list` from scratch — a rescan-on-open flash — every single time the
// island's Loader recreated WifiTab) and so the connect/forget/add-network
// logic lives in one place instead of being tangled into the view.
//
// Quickshell.Networking's own WifiDevice.networks only ever surfaced the
// currently-connected network plus ones with a saved NM profile — a network
// merely visible in range (never connected, unsaved) never appeared, so
// "available networks" was actually just "known networks". nmcli sees
// everything NetworkManager's scan cache has, so the list itself is sourced
// from nmcli instead; Quickshell.Networking is still used for the plain
// on/off toggle.
QtObject {
    id: root

    readonly property var wifiDevice: {
        const devices = Networking.devices ? Networking.devices.values : [];
        return devices.find(d => d.type === DeviceType.Wifi) || null;
    }

    property var networks: []
    property var knownNames: []

    property string expandedNetwork: ""
    property string connectError: ""
    property bool scanning: false
    property bool loaded: false

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

    function refreshNetworks() {
        listProc.running = false;
        listProc.running = true;
        knownProc.running = false;
        knownProc.running = true;
    }

    property Process listProc: Process {
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const byName = {};
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    const f = root.parseTerseLine(line);
                    const inUse = f[0] === "*";
                    const ssid = f[1] || "";
                    const signal = parseInt(f[2], 10) || 0;
                    const security = f[3] || "";
                    if (!ssid || ssid === "--") continue;
                    const existing = byName[ssid];
                    if (!existing || signal > existing.signal) {
                        byName[ssid] = { ssid, signal, security, secured: !!security && security !== "--", connected: inUse || (existing ? existing.connected : false) };
                    } else if (inUse) {
                        existing.connected = true;
                    }
                }
                const list = Object.values(byName);
                list.sort((a, b) => (b.connected - a.connected) || (b.signal - a.signal));
                root.networks = list;
                root.loaded = true;
            }
        }
    }

    property Process knownProc: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    const f = root.parseTerseLine(line);
                    if (f[1] === "802-11-wireless" || f[1] === "wifi") names.push(f[0]);
                }
                root.knownNames = names;
            }
        }
    }

    function isKnown(ssid) { return root.knownNames.indexOf(ssid) !== -1; }

    // Disconnect if already connected; otherwise try the fastest path first
    // (a saved profile, or no secrets needed) and only fall back to the
    // password prompt once nmcli actually reports it needs one.
    function activate(net) {
        root.connectError = "";
        if (net.connected) { root.runConnect(["nmcli", "connection", "down", "id", net.ssid], net.ssid); return; }
        if (root.expandedNetwork === net.ssid) { root.expandedNetwork = ""; return; }
        if (root.isKnown(net.ssid)) { root.runConnect(["nmcli", "connection", "up", "id", net.ssid], net.ssid); return; }
        if (!net.secured) { root.runConnect(["nmcli", "device", "wifi", "connect", net.ssid], net.ssid); return; }
        root.expandedNetwork = net.ssid;
    }

    function submitPassword(ssid, password) {
        if (!password) return;
        root.connectError = "";
        root.runConnect(["nmcli", "device", "wifi", "connect", ssid, "password", password], ssid);
    }

    function forget(ssid) {
        forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
        forgetProc.running = false;
        forgetProc.running = true;
    }

    property Process forgetProc: Process { onExited: root.refreshNetworks() }

    function runConnect(cmd, ssid) {
        connectProc.pendingSsid = ssid;
        connectProc.errText = "";
        connectProc.command = cmd;
        connectProc.running = false;
        connectProc.running = true;
    }

    property Process connectProc: Process {
        property string pendingSsid: ""
        property string errText: ""
        stderr: StdioCollector {
            onStreamFinished: connectProc.errText = text
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.expandedNetwork = connectProc.pendingSsid;
                root.connectError = /secret|password|key|802-1x|pmf/i.test(connectProc.errText)
                    ? "Incorrect password" : "Couldn't connect";
            } else {
                root.expandedNetwork = "";
                root.connectError = "";
            }
            root.refreshNetworks();
        }
    }

    // Quickshell.Networking's WifiDevice only exposes `scannerEnabled` (a
    // continuous on/off switch), not an on-demand rescan — `nmcli device
    // wifi rescan` is what actually kicks NetworkManager into refreshing
    // its scan cache right away.
    function scan() {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = true;
        root.scanning = true;
        scanProc.command = ["nmcli", "device", "wifi", "rescan"];
        scanProc.running = false;
        scanProc.running = true;
    }

    property Process scanProc: Process { onExited: scanTimer.restart() }
    // The rescan call returns almost immediately but the scan itself takes
    // a couple seconds; give it a moment before re-listing.
    property Timer scanTimer: Timer {
        interval: 2500
        onTriggered: { root.scanning = false; root.refreshNetworks(); }
    }

    // Manually-entered networks (typically hidden, so they never show up in
    // the scanned list above) go through the same nmcli path but need
    // explicit security settings since there's nothing to scan yet.
    // SSID/interface/password are passed as $1/$2/$3 positional params
    // rather than interpolated into the script text, so nothing the user
    // types (quotes, `;`, backticks, ...) can break out into shell syntax.
    readonly property var securityOptions: [
        { key: "wpa", label: "WPA/WPA2 Personal" },
        { key: "wpa3", label: "WPA3 Personal" },
        { key: "wep", label: "WEP" },
        { key: "open", label: "Open (no password)" }
    ]

    function addNetworkScript(security) {
        let secArgs = "";
        if (security === "wpa") secArgs = "wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"$3\"";
        else if (security === "wpa3") secArgs = "wifi-sec.key-mgmt sae wifi-sec.psk \"$3\"";
        else if (security === "wep") secArgs = "wifi-sec.key-mgmt none wifi-sec.wep-key-type key wifi-sec.wep-key0 \"$3\"";
        return "set -e\n"
            + "nmcli connection delete \"$1\" >/dev/null 2>&1 || true\n"
            + "nmcli connection add type wifi con-name \"$1\" ifname \"$2\" ssid \"$1\" -- wifi.hidden yes"
            + (secArgs ? " " + secArgs : "") + "\n"
            + "nmcli connection up \"$1\"\n";
    }

    function addNetwork(ssid, ifname, password, security) {
        if (!ssid || !ifname) return;
        addNetworkProc.command = ["sh", "-c", root.addNetworkScript(security), "_", ssid, ifname, password];
        addNetworkProc.running = false;
        addNetworkProc.running = true;
    }

    property Process addNetworkProc: Process { onExited: root.refreshNetworks() }

    // First-ever load only — after that, WifiTab just reads the cached
    // state above instead of re-scanning every time it's opened. The scan
    // button (or any connect/forget/add action) refreshes it explicitly.
    Component.onCompleted: refreshNetworks()
}
