pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth as QsBluetooth

// Reactive Bluetooth state backed by Quickshell's native BlueZ integration.
// Keep this adapter's public API stable so BluetoothIsland, MediaCard, and Osd do
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
        root._forgetUserDisconnect(id);
        // Retry-eligible without touching trust, so a flaky first connect
        // (e.g. Soundcore R60i) doesn't die silently and the Auto-connect
        // toggle keeps whatever the user set.
        root._requestedId = id;
        device.connect();
        root._scheduleReconnect(true);
        return true;
    }

    function disconnect(id) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("disconnect", "Device is no longer available"); return false; }
        // Kept until the device connects again, so the reconnect loop
        // doesn't undo a manual disconnect 5s later.
        root._userDisconnectedIds = Object.assign({}, root._userDisconnectedIds, { [id]: true });
        if (root._requestedId === id) root._requestedId = "";
        device.disconnect();
        return true;
    }

    function forget(id) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("forget", "Device is no longer available"); return false; }
        if (root.autoConnectId === id) root._cancelReconnect();
        root._forgetUserDisconnect(id);
        if (root._requestedId === id) root._requestedId = "";
        device.forget();
        return true;
    }

    function setAutoConnect(id, enabled) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("set trusted", "Device is no longer available"); return false; }
        device.trusted = enabled;
        if (enabled) root._scheduleReconnect(true);
        else if (root.autoConnectId === id) {
            // Drop the in-flight attempt so it can't announce itself later.
            root._cancelReconnect();
            root._scheduleReconnect(false);
        }
        return true;
    }

    // ─── Low-battery alert ───────────────────────────────────────────────
    // "Warn only when action matters" — one alert per device per drop below
    // the threshold, not a running list. Same dedup + hysteresis shape as
    // Calendar.qml's meeting alert: fire once, and only re-fire after the
    // device has recovered well above the threshold (recharged) and dropped
    // again, so it doesn't spam every scan while just idling at 19%.
    readonly property int lowBatteryThreshold: 20
    property var lowBatteryAlert: null
    property var _lowBatteryAlerted: ({})

    function dismissLowBattery() { root.lowBatteryAlert = null; }

    function _scanLowBattery() {
        if (root.lowBatteryAlert) return;
        for (const device of root.state.devices) {
            if (!device.connected || !device.batteryAvailable) continue;
            const pct = Math.round(device.battery * 100);
            if (pct <= root.lowBatteryThreshold) {
                if (root._lowBatteryAlerted[device.id]) continue;
                root._lowBatteryAlerted = Object.assign({}, root._lowBatteryAlerted, { [device.id]: true });
                root.lowBatteryAlert = device;
                return;
            }
            if (pct > root.lowBatteryThreshold + 10 && root._lowBatteryAlerted[device.id]) {
                const next = Object.assign({}, root._lowBatteryAlerted);
                delete next[device.id];
                root._lowBatteryAlerted = next;
            }
        }
    }

    property Timer lowBatteryTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._scanLowBattery()
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
        profileProc.errText = "";
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
    // BlueZ bond, and for the device the user last asked to connect. Bonded
    // devices reconnect on their own. Attempts are finite and increasingly
    // spaced, and the budget resets only on events from a target device or
    // a user action. On battery it runs only while the Bluetooth panel is
    // open.
    property int reconnectAttempt: 0
    readonly property int maxReconnectAttempts: 4
    readonly property var reconnectDelays: [5000, 15000, 30000, 60000]
    property bool _autoDiscovery: false
    // Set by disconnect(id); excludes those devices from reconnect targeting
    // until they connect again. See disconnect()/connect() and onConnectedChanged.
    property var _userDisconnectedIds: ({})
    // Set by connect(id); retried even when bonded, until it connects.
    property string _requestedId: ""
    readonly property BluetoothReconnectCore _reconnectCore: BluetoothReconnectCore {}

    function _forgetUserDisconnect(id) {
        if (!root._userDisconnectedIds[id]) return;
        const next = Object.assign({}, root._userDisconnectedIds);
        delete next[id];
        root._userDisconnectedIds = next;
    }

    function _isReconnectTarget(device) {
        return root._reconnectCore.isTarget(device, root._userDisconnectedIds, root._requestedId);
    }

    function _reconnectTarget() {
        return root._reconnectCore.reconnectTarget(root.nativeDevices, root._userDisconnectedIds, root._requestedId);
    }

    function _idleReconnectTarget() {
        return root._reconnectCore.idleReconnectTarget(root.nativeDevices, root._userDisconnectedIds, root._requestedId, root.autoConnectId);
    }

    // True while any device is mid-pair or mid-connect, including one the
    // user is connecting by hand. Toggling discovery then starves its SDP
    // negotiation, so the reconnect loop backs off.
    function _anyDeviceNegotiating() {
        return root._reconnectCore.anyDeviceNegotiating(root.nativeDevices);
    }

    function _stopAutoDiscovery() {
        if (root._autoDiscovery && root.adapter && root.adapter.discovering)
            root.adapter.discovering = false;
        root._autoDiscovery = false;
    }

    function _cancelReconnect() {
        reconnectTimer.stop();
        reconnectFinalCheckTimer.stop();
        root.reconnectAttempt = 0;
        root.autoConnectId = "";
        root._stopAutoDiscovery();
    }

    function _scheduleReconnect(resetBudget) {
        const device = root._reconnectTarget();
        if (!root.adapter || !root.adapter.enabled || !device || (UPower.onBattery && !root.active)) {
            root._cancelReconnect();
            return;
        }
        if (resetBudget) {
            root.reconnectAttempt = 0;
            // A pending final check belongs to the previous budget; letting
            // it fire would stop discovery mid-cycle and report a failure.
            reconnectFinalCheckTimer.stop();
        }
        if (root.reconnectAttempt >= root.maxReconnectAttempts || reconnectTimer.running) return;
        reconnectTimer.interval = root.reconnectDelays[root.reconnectAttempt];
        reconnectTimer.start();
    }

    function _attemptReconnect() {
        const device = root._reconnectTarget();
        if (!device || !root.adapter || !root.adapter.enabled || (UPower.onBattery && !root.active)) {
            root._cancelReconnect();
            return;
        }

        // A connect/pair attempt (ours or the user's) may still be in
        // flight — some devices (Soundcore R60i) take 15-20s to finish SDP.
        // Toggling discovery mid-attempt starves that negotiation and drops
        // the link. Back off. This still uses up one attempt, so a device
        // stuck negotiating can't stall the loop forever.
        if (root._anyDeviceNegotiating()) {
            if (root.reconnectAttempt >= root.maxReconnectAttempts) {
                root._cancelReconnect();
                return;
            }
            root.reconnectAttempt++;
            root._scheduleReconnect(false);
            return;
        }

        // Never null here: a target exists and none are negotiating.
        const idleDevice = root._idleReconnectTarget();

        if (!root.adapter.discovering) {
            root._autoDiscovery = true;
            root.adapter.discovering = true;
        }

        root.autoConnectId = idleDevice.address || idleDevice.dbusPath;
        root.reconnectAttempt++;
        if (idleDevice.paired) idleDevice.connect();
        else {
            root.pendingPairId = root.autoConnectId;
            idleDevice.pair();
        }
        if (root.reconnectAttempt >= root.maxReconnectAttempts) {
            // Give this last attempt its full window before declaring
            // failure — it's still negotiating, not done yet.
            reconnectFinalCheckTimer.restart();
        } else {
            root._scheduleReconnect(false);
        }
    }

    property Timer reconnectFinalCheckTimer: Timer {
        interval: root.reconnectDelays[root.reconnectDelays.length - 1]
        onTriggered: {
            root._stopAutoDiscovery();
            const device = root._deviceForId(root.autoConnectId);
            if (device && !device.connected) root._reportError("reconnect", "Could not reconnect to " + (device.name || device.deviceName || "device"));
        }
    }

    property Timer reconnectTimer: Timer {
        onTriggered: root._attemptReconnect()
    }

    // Bound to the ObjectModel, not its values array, so discovery adding
    // a device creates one watcher instead of rebuilding them all.
    property Instantiator deviceWatchers: Instantiator {
        model: root.adapter ? root.adapter.devices : null
        delegate: QtObject {
            required property var modelData
            property Connections watcher: Connections {
                target: modelData

                function onPairedChanged() {
                    const id = modelData.address || modelData.dbusPath;
                    if (id === root.pendingPairId && modelData.paired) {
                        root.pendingPairId = "";
                        // Trust on first pair so Auto-connect starts on.
                        // Later connects leave the user's choice alone.
                        modelData.trusted = true;
                        if (!modelData.connected) modelData.connect();
                    }
                }

                function onConnectedChanged() {
                    const id = modelData.address || modelData.dbusPath;
                    if (modelData.connected) {
                        root._forgetUserDisconnect(id);
                        if (id === root._requestedId) root._requestedId = "";
                        if (id === root.autoConnectId) {
                            root.deviceAutoConnected(modelData.name || modelData.deviceName);
                            // The target is back. Fresh budget for any
                            // other device that's still missing.
                            root._cancelReconnect();
                            root._scheduleReconnect(true);
                        } else {
                            // Another device's event must not refill the
                            // budget of a target that stays unreachable.
                            root._scheduleReconnect(false);
                        }
                    } else if (root._isReconnectTarget(modelData)) {
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
