pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth as QsBluetooth

// Reactive Bluetooth state backed by Quickshell's native BlueZ integration.
// Keep this adapter's public API stable so BluetoothTab, MediaCard, and Osd do
// not need to know which backend owns device discovery and actions.
QtObject {
    id: root

    readonly property var adapter: QsBluetooth.Bluetooth.defaultAdapter
    readonly property var nativeDevices: root.adapter && root.adapter.devices
        ? root.adapter.devices.values : []

    property bool active: false
    property string lastError: ""
    property var cards: []

    readonly property var _audioSinks: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink)
        : []
    readonly property PwObjectTracker _audioTracker: PwObjectTracker { objects: root._audioSinks }
    readonly property BluetoothDeviceCore _core: BluetoothDeviceCore {
        devices: root.nativeDevices
        audioNodes: root._audioSinks
    }
    readonly property var state: ({
        available: !!root.adapter,
        powered: !!root.adapter && root.adapter.enabled,
        discoverable: !!root.adapter && root.adapter.discoverable,
        scanning: !!root.adapter && root.adapter.discovering,
        lastError: root.lastError,
        devices: root._core.state.devices
    })

    signal errorOccurred(string action, string message)
    signal deviceAutoConnected(string name)

    function _deviceForId(id) {
        return root.nativeDevices.find(device => device.address === id || device.dbusPath === id) || null;
    }

    function _reportError(action, message) {
        root.lastError = action + ": " + message;
        root.errorOccurred(action, message);
        errorClearTimer.restart();
    }

    function setActive(active) {
        if (root.active === active) return;
        root.active = active;
        if (active) cardsProc.running = true;
        root._scheduleReconnect(false);
    }

    function refreshAll() {
        // Native BlueZ objects update from D-Bus signals. Only PipeWire card
        // profiles still need an external snapshot, and only while visible.
        if (root.active) {
            cardsProc.running = false;
            cardsProc.running = true;
        }
    }

    function setPowered(enabled) {
        if (!root.adapter) { root._reportError("power", "No Bluetooth adapter"); return; }
        root.adapter.enabled = enabled;
        if (!enabled) root._cancelReconnect();
    }

    function setScanning(scanning) {
        if (!root.adapter) { root._reportError("discovery", "No Bluetooth adapter"); return; }
        root._autoDiscovery = false;
        root.adapter.discovering = scanning;
    }

    function setDiscoverable(discoverable) {
        if (!root.adapter) { root._reportError("discoverable", "No Bluetooth adapter"); return; }
        if (discoverable) root.adapter.pairable = true;
        root.adapter.discoverable = discoverable;
    }

    property string pendingPairId: ""
    property string autoConnectId: ""

    function pair(id) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("pair", "Device is no longer available"); return false; }
        root.pendingPairId = id;
        device.pair();
        return true;
    }

    function connect(id) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("connect", "Device is no longer available"); return false; }
        device.connect();
        return true;
    }

    function disconnect(id) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("disconnect", "Device is no longer available"); return false; }
        device.disconnect();
        return true;
    }

    function forget(id) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("forget", "Device is no longer available"); return false; }
        if (root.autoConnectId === id) root._cancelReconnect();
        device.forget();
        return true;
    }

    function setAutoConnect(id, enabled) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("set trusted", "Device is no longer available"); return false; }
        device.trusted = enabled;
        if (enabled) root._scheduleReconnect(true);
        return true;
    }

    // PipeWire's QML API does not expose card-profile changes, so this one
    // action keeps pactl. Card enumeration happens only while this panel is
    // active, never on an idle timer.
    function setAudioProfile(id, category) {
        const device = root._deviceForId(id);
        if (!device || !device.address) return false;
        const cardName = "bluez_card." + device.address.toUpperCase().replace(/:/g, "_");
        const card = root.cards.find(candidate => candidate.name === cardName);
        if (!card || !card.profiles) return false;
        const prefix = category === "call" ? "headset-head-unit" : "a2dp-sink";
        const candidates = Object.keys(card.profiles)
            .filter(name => (name === prefix || name.startsWith(prefix + "-")) && card.profiles[name].available)
            .sort((a, b) => card.profiles[b].priority - card.profiles[a].priority);
        if (candidates.length === 0) return false;
        profileProc.command = ["pactl", "set-card-profile", cardName, candidates[0]];
        profileProc.running = true;
        return true;
    }

    property Process profileProc: Process {
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: profileProc.errText = text }
        onExited: exitCode => {
            if (exitCode !== 0) root._reportError("audio profile", profileProc.errText.trim() || "Failed");
            root.refreshAll();
        }
    }

    property Process cardsProc: Process {
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.cards = JSON.parse(text) || []; }
                catch (error) { root._reportError("audio profiles", "Invalid pactl response"); }
            }
        }
    }

    property Timer errorClearTimer: Timer {
        interval: 6000
        onTriggered: root.lastError = ""
    }

    // Exceptional reconnect path for trusted devices that do not retain a
    // BlueZ bond. Attempts are finite and increasingly spaced. On battery it
    // runs only while the Bluetooth panel is open.
    property int reconnectAttempt: 0
    readonly property int maxReconnectAttempts: 4
    readonly property var reconnectDelays: [5000, 15000, 30000, 60000]
    property bool _autoDiscovery: false

    function _missingTrustedDevice() {
        return root.nativeDevices.find(device => device.trusted && !device.connected) || null;
    }

    function _stopAutoDiscovery() {
        if (root._autoDiscovery && root.adapter && root.adapter.discovering)
            root.adapter.discovering = false;
        root._autoDiscovery = false;
    }

    function _cancelReconnect() {
        reconnectTimer.stop();
        root.reconnectAttempt = 0;
        root.autoConnectId = "";
        root._stopAutoDiscovery();
    }

    function _scheduleReconnect(resetBudget) {
        const device = root._missingTrustedDevice();
        if (!root.adapter || !root.adapter.enabled || !device || (UPower.onBattery && !root.active)) {
            root._cancelReconnect();
            return;
        }
        if (resetBudget) root.reconnectAttempt = 0;
        if (root.reconnectAttempt >= root.maxReconnectAttempts || reconnectTimer.running) return;
        reconnectTimer.interval = root.reconnectDelays[root.reconnectAttempt];
        reconnectTimer.start();
    }

    function _attemptReconnect() {
        const device = root._missingTrustedDevice();
        if (!device || !root.adapter || !root.adapter.enabled || (UPower.onBattery && !root.active)) {
            root._cancelReconnect();
            return;
        }

        if (!root.adapter.discovering) {
            root._autoDiscovery = true;
            root.adapter.discovering = true;
        }

        root.autoConnectId = device.address || device.dbusPath;
        root.reconnectAttempt++;
        if (!device.pairing && device.state !== QsBluetooth.BluetoothDeviceState.Connecting) {
            if (device.paired) device.connect();
            else {
                root.pendingPairId = root.autoConnectId;
                device.pair();
            }
        }
        root._scheduleReconnect(false);
        if (root.reconnectAttempt >= root.maxReconnectAttempts) root._stopAutoDiscovery();
    }

    property Timer reconnectTimer: Timer {
        onTriggered: root._attemptReconnect()
    }

    property Instantiator deviceWatchers: Instantiator {
        model: root.nativeDevices
        delegate: QtObject {
            required property var modelData
            property Connections watcher: Connections {
                target: modelData

                function onPairedChanged() {
                    const id = modelData.address || modelData.dbusPath;
                    if (id === root.pendingPairId && modelData.paired) {
                        root.pendingPairId = "";
                        if (!modelData.connected) modelData.connect();
                    }
                }

                function onConnectedChanged() {
                    const id = modelData.address || modelData.dbusPath;
                    if (modelData.connected) {
                        if (id === root.autoConnectId) root.deviceAutoConnected(modelData.name || modelData.deviceName);
                        root._cancelReconnect();
                    } else if (modelData.trusted) {
                        root._scheduleReconnect(true);
                    }
                }

                function onTrustedChanged() {
                    if (modelData.trusted) root._scheduleReconnect(true);
                }
            }
        }
    }

    onNativeDevicesChanged: root._scheduleReconnect(false)

    property Connections adapterWatcher: Connections {
        target: root.adapter
        function onEnabledChanged() { root._scheduleReconnect(true); }
    }

    property Connections batteryWatcher: Connections {
        target: UPower
        function onOnBatteryChanged() { root._scheduleReconnect(false); }
    }

    Component.onCompleted: root._scheduleReconnect(true)
}
