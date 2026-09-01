pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

// Bluetooth state + actions, talking to BlueZ directly over the system
// D-Bus (org.bluez.Adapter1 / org.bluez.Device1 / ObjectManager) via
// `busctl`, instead of Quickshell's built-in Quickshell.Bluetooth module.
// Mirrors the WifiNetworks.qml pattern: one reusable Process per action,
// `command` reassigned and `running` retoggled to fire it again.
//
// --- Why busctl instead of a real D-Bus signal subscription -----------
// BlueZ's own reactive updates (InterfacesAdded/Removed, PropertiesChanged)
// would normally come from `busctl monitor org.bluez`, but that requires
// becoming a D-Bus *monitor*, which stock system-bus policy on this machine
// denies to non-root (`BecomeMonitor failed: Access denied`). There is also
// no generic Quickshell QML API for exporting a D-Bus object, so this layer
// can't register a real org.bluez.Agent1 either — pairing here only works
// for devices BlueZ auto-accepts without agent interaction (headsets/
// earbuds in "Just Works" mode; the common case). Given that, this service
// polls `GetManagedObjects` instead of subscribing to signals, plus does an
// immediate refresh after every action it initiates for instant feedback.
QtObject {
    id: root

    property var devices: []
    property bool available: false
    property bool powered: false
    property bool discoverable: false
    property bool scanning: false
    property string adapterPath: "/org/bluez/hci0"

    property bool active: false // panel visibility — gates background polling
    property string pairingPath: ""

    property string lastError: ""
    readonly property var _audioSinks: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
        : []
    readonly property PwObjectTracker _audioTracker: PwObjectTracker { objects: root._audioSinks }
    readonly property BluetoothDeviceCore _core: BluetoothDeviceCore { devices: root.devices; audioNodes: root._audioSinks }
    readonly property var state: ({
        available: root.available,
        powered: root.powered,
        discoverable: root.discoverable,
        scanning: root.scanning,
        lastError: root.lastError,
        devices: root._core.state.devices
    })
    signal errorOccurred(string action, string message)
    signal deviceAutoConnected(string name)

    function setActive(active) {
        if (root.active === active) return;
        root.active = active;
        if (active) root.refreshAll();
    }

    function _pathForId(id) {
        const device = root.devices.find(d => (d.address || d.path) === id);
        return device ? device.path : "";
    }

    function setScanning(scanning) { return scanning ? root.startDiscovery() : root.stopDiscovery(); }
    function pair(id) { const path = root._pathForId(id); return path ? root._pairPath(path) : false; }
    function connect(id) { const path = root._pathForId(id); return path ? root._connectPath(path) : false; }
    function disconnect(id) { const path = root._pathForId(id); return path ? root._disconnectPath(path) : false; }
    function forget(id) { const path = root._pathForId(id); return path ? root._forgetPath(path) : false; }
    function setAutoConnect(id, enabled) { const path = root._pathForId(id); return path ? root._setTrustedPath(path, enabled) : false; }

    // busctl only prints the D-Bus error's human message ("Call failed:
    // <message>"), not its dotted name (org.bluez.Error.*) — sd-bus derives
    // that message from the error name's last component, so this reverses
    // it back to a friendly explanation on a best-effort basis.
    readonly property var errorMessages: ({
        "failed": "Bluetooth operation failed",
        "not ready": "Adapter isn't ready yet",
        "not available": "Not available on this device",
        "already connected": "Device is already connected",
        "already exists": "Device is already paired",
        "does not exist": "Device is no longer known to BlueZ (try scanning again)",
        "authentication failed": "Pairing was rejected or the PIN was wrong",
        "authentication canceled": "Pairing was canceled",
        "authentication cancelled": "Pairing was canceled",
        "authentication rejected": "Pairing was rejected by the device",
        "authentication timeout": "Pairing timed out",
        "connection attempt failed": "The device dropped the connection while setting up (common right after pairing on some headsets)",
        "in progress": "Already in progress"
    })

    function reportError(action, stderrText) {
        const raw = (stderrText || "").replace(/^Call failed:\s*/i, "").trim();
        const friendly = root.errorMessages[raw.toLowerCase()] || raw || "Unknown D-Bus error";
        root.lastError = action + ": " + friendly;
        console.warn("[Bluetooth]", action, "failed —", raw || "(no message)");
        root.errorOccurred(action, friendly);
        errorClearTimer.restart();
    }

    property Timer errorClearTimer: Timer { interval: 6000; onTriggered: root.lastError = "" }

    property Timer pollTimer: Timer {
        interval: root.scanning ? 1500 : 4000
        running: root.active
        repeat: true
        onTriggered: root.refreshAll()
    }

    // --- Background auto-reconnect (runs whether or not the panel is open) --
    // BlueZ normally reconnects a Trusted device on its own once the
    // peripheral pages back in — no action needed here. But some devices
    // (confirmed for the Soundcore R60i NC via direct D-Bus inspection: it
    // reports Bonded: false, and Paired flips back to false the moment it
    // disconnects) never persist a real bond, so BlueZ has no pairing record
    // left to reconnect to. Compensate by periodically re-discovering and
    // re-pairing/connecting any Trusted device that isn't currently
    // connected, and keeping discovery running in the background while one
    // is outstanding so BlueZ has a chance to see it page back in at all.
    property var lastReconnectAttempt: ({})
    readonly property int reconnectCooldownMs: 20000

    // Set right before firing the Pair()/Connect() call below, so
    // connectProc's onExited can tell an auto-triggered connect apart from
    // a user-initiated one (same shared Process either way) and only emit
    // deviceAutoConnected for the former.
    property string autoConnectPath: ""
    property string autoConnectName: ""

    property Timer backgroundPollTimer: Timer {
        interval: 15000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAll()
    }

    function maybeAutoReconnect(list) {
        if (!root.powered) return;
        // Never stomp on an in-flight pair/connect — including one this same
        // function started a moment ago, since reassigning pairProc/
        // connectProc's `command` while they're still running would kill and
        // restart them mid-call (including a legitimate user-initiated one).
        if (root.pairProc.running || root.connectProc.running) return;

        const pending = list.filter(d => d.trusted && !d.connected && !d.pairing);
        if (pending.length === 0) return;

        // Only actually fire Pair()/Connect() at a device BlueZ has recently
        // seen advertise (nonzero RSSI) — that's the only "is this thing
        // physically nearby" signal exposed over D-Bus. Without this check
        // an out-of-range trusted device gets a failing Connect() call every
        // cooldown window forever instead of just waiting quietly.
        const nearby = pending.filter(d => d.rssi !== 0);

        const now = Date.now();
        const dev = nearby.find(d => (now - (root.lastReconnectAttempt[d.path] || 0)) >= root.reconnectCooldownMs);
        if (dev) {
            root.lastReconnectAttempt[dev.path] = now;
            root.autoConnectPath = dev.path;
            root.autoConnectName = dev.name || dev.alias;
            // Paired devices just need a Connect(); devices that lost their
            // bond (like the R60i) need a fresh Pair() — pairDevice() already
            // chains into connectDevice() on success.
            if (dev.paired) root._connectPath(dev.path);
            else root._pairPath(dev.path);
        }

        // Keep discovery alive while any trusted device is still missing —
        // classic BT devices only show up in GetManagedObjects once BlueZ
        // has actually seen them via an active inquiry, and RSSI (used above
        // to gate connect attempts on proximity) only gets populated/
        // refreshed that same way.
        if (!root.scanning) root.startDiscovery();
    }

    // --- Discovery -----------------------------------------------------

    // BlueZ ties an active discovery session to the D-Bus connection that
    // called StartDiscovery, and ends the session the instant that
    // connection closes. A one-shot `busctl call ... StartDiscovery` opens
    // its own connection just for that call and exits (closing it)
    // immediately after — so discovery was being silently stopped within
    // milliseconds every time, before it could ever be observed as active.
    // Keeping a single long-lived `bluetoothctl` process open for the scan
    // (and killing it to stop) keeps the connection — and discovery —
    // alive instead. `--timeout` runs bluetoothctl non-interactively, which
    // does NOT register its own pairing agent (only the full interactive
    // REPL does) — that matters because a registered agent would fight the
    // "just works" auto-accept pairing this service relies on (see
    // pairDevice below) if a scan happens to be running during a pair. The
    // timeout is just a safety cap in case stopDiscovery() never gets
    // called; normal start/stop is driven directly by these two functions.
    function startDiscovery() {
        if (discoveryProc.running) return;
        discoveryProc.command = ["bluetoothctl", "--timeout", "120", "scan", "on"];
        discoveryProc.running = true;
    }

    function stopDiscovery() {
        discoveryProc.running = false;
    }

    property Process discoveryProc: Process {
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: discoveryProc.errText = text }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.reportError("discovery", discoveryProc.errText);
            root.refreshAll();
        }
    }

    // --- Adapter power / discoverable -----------------------------------

    function setPowered(v) {
        powerProc.command = ["busctl", "--system", "set-property", "org.bluez", root.adapterPath, "org.bluez.Adapter1", "Powered", "b", v ? "true" : "false"];
        powerProc.running = false;
        powerProc.running = true;
    }

    property Process powerProc: Process {
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: powerProc.errText = text }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.reportError("power", powerProc.errText);
            root.refreshAll();
        }
    }

    function setDiscoverable(v) {
        discoverableProc.command = ["busctl", "--system", "set-property", "org.bluez", root.adapterPath, "org.bluez.Adapter1", "Discoverable", "b", v ? "true" : "false"];
        discoverableProc.running = false;
        discoverableProc.running = true;
    }

    property Process discoverableProc: Process {
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: discoverableProc.errText = text }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.reportError("discoverable", discoverableProc.errText);
            root.refreshAll();
        }
    }

    // --- Device actions --------------------------------------------------
    // Pairing and connecting are always kept as separate D-Bus calls/states
    // (never inferred from one another): a device can be Paired:true and
    // Connected:false at the same time — that's a connect/profile failure,
    // not a pairing failure, and is exactly what the Soundcore R60i NC does
    // (pairs fine, then drops during the audio-profile handshake).

    function _pairPath(path) {
        root.pairingPath = path;
        pairProc.targetPath = path;
        pairProc.command = ["busctl", "--system", "call", "org.bluez", path, "org.bluez.Device1", "Pair"];
        pairProc.running = false;
        pairProc.running = true;
        return true;
    }

    property Process pairProc: Process {
        property string targetPath: ""
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: pairProc.errText = text }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.pairingPath = "";
                root.reportError("pair", pairProc.errText);
                root.refreshAll();
            } else {
                // Pair() succeeding does NOT mean Connected is true — BlueZ
                // often doesn't auto-connect audio profiles. Try to connect
                // explicitly, then read the real Connected property back
                // from BlueZ in connectProc's handler rather than assuming.
                root._connectPath(pairProc.targetPath);
            }
        }
    }

    function _connectPath(path) {
        connectProc.targetPath = path;
        connectProc.command = ["busctl", "--system", "call", "org.bluez", path, "org.bluez.Device1", "Connect"];
        connectProc.running = false;
        connectProc.running = true;
        return true;
    }

    property Process connectProc: Process {
        property string targetPath: ""
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: connectProc.errText = text }
        onExited: (exitCode) => {
            root.pairingPath = "";
            if (exitCode !== 0) {
                root.reportError("connect", connectProc.errText);
            } else if (connectProc.targetPath !== "" && connectProc.targetPath === root.autoConnectPath) {
                root.deviceAutoConnected(root.autoConnectName);
            }
            if (connectProc.targetPath === root.autoConnectPath) root.autoConnectPath = "";
            root.refreshAll(); // always re-read Paired/Connected from BlueZ, win or lose
        }
    }

    function _disconnectPath(path) {
        disconnectProc.command = ["busctl", "--system", "call", "org.bluez", path, "org.bluez.Device1", "Disconnect"];
        disconnectProc.running = false;
        disconnectProc.running = true;
        return true;
    }

    property Process disconnectProc: Process {
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: disconnectProc.errText = text }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.reportError("disconnect", disconnectProc.errText);
            root.refreshAll();
        }
    }

    function _forgetPath(path) {
        removeProc.command = ["busctl", "--system", "call", "org.bluez", root.adapterPath, "org.bluez.Adapter1", "RemoveDevice", "o", path];
        removeProc.running = false;
        removeProc.running = true;
        return true;
    }

    property Process removeProc: Process {
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: removeProc.errText = text }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.reportError("forget", removeProc.errText);
            root.refreshAll();
        }
    }

    function _setTrustedPath(path, trusted) {
        trustProc.command = ["busctl", "--system", "set-property", "org.bluez", path, "org.bluez.Device1", "Trusted", "b", trusted ? "true" : "false"];
        trustProc.running = false;
        trustProc.running = true;
        return true;
    }

    property Process trustProc: Process {
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: trustProc.errText = text }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.reportError("set trusted", trustProc.errText);
            root.refreshAll();
        }
    }

    // --- State: ObjectManager snapshot ------------------------------------

    function refreshAll() {
        getObjectsProc.running = false;
        getObjectsProc.running = true;
    }

    property Process getObjectsProc: Process {
        command: ["busctl", "--system", "--json=short", "call", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stdout: StdioCollector { onStreamFinished: root.applyManagedObjects(text) }
    }

    function applyManagedObjects(text) {
        let parsed;
        try {
            parsed = JSON.parse(text);
        } catch (e) {
            console.warn("[Bluetooth] failed to parse GetManagedObjects:", e);
            return;
        }
        const managed = (parsed.data && parsed.data[0]) || {};

        let adapterPath = "";
        let adapterProps = null;
        for (const path in managed) {
            const a = managed[path]["org.bluez.Adapter1"];
            if (a) { adapterPath = path; adapterProps = a; break; }
        }
        root.available = !!adapterPath;
        root.adapterPath = adapterPath || root.adapterPath || "/org/bluez/hci0";
        root.powered = !!(adapterProps && adapterProps.Powered && adapterProps.Powered.data);
        root.discoverable = !!(adapterProps && adapterProps.Discoverable && adapterProps.Discoverable.data);
        root.scanning = !!(adapterProps && adapterProps.Discovering && adapterProps.Discovering.data);

        const list = [];
        for (const path in managed) {
            const dev1 = managed[path]["org.bluez.Device1"];
            if (!dev1) continue;
            const battery = managed[path]["org.bluez.Battery1"];
            const get = (k, d) => (dev1[k] ? dev1[k].data : d);
            const name = get("Name", "") || get("Alias", "") || get("Address", "");
            list.push({
                path: path,
                name: name,
                alias: get("Alias", name),
                address: get("Address", ""),
                icon: get("Icon", ""),
                paired: !!get("Paired", false),
                connected: !!get("Connected", false),
                trusted: !!get("Trusted", false),
                rssi: get("RSSI", 0),
                uuids: get("UUIDs", []),
                batteryAvailable: !!battery,
                battery: (battery && battery.Percentage) ? battery.Percentage.data / 100 : 0,
                pairing: path === root.pairingPath
            });
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        root.devices = list;
        root.maybeAutoReconnect(list);
    }

    Component.onCompleted: root.refreshAll()
}
