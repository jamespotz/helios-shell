pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth as QsBluetooth

// Reactive Bluetooth state backed by Quickshell's native BlueZ integration.
// Keep this adapter's public API stable so BluetoothDestination, MediaCard, and Osd do
// not need to know which backend owns device discovery and actions.
QtObject {
    id: root

    readonly property var adapter: QsBluetooth.Bluetooth.defaultAdapter
    readonly property var nativeDevices: root.adapter && root.adapter.devices
        ? root.adapter.devices.values : []

    property bool active: false
    property string lastError: ""

    // Its own sink list rather than Audio.sinks: Audio reads Bluetooth.state,
    // so reading Audio here would make the two singletons wait on each other.
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
    signal deviceConnectionChanged(bool connected)

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
        if (root.adapter && root.adapter.enabled) root.setScanning(active);
    }

    function setPowered(enabled) {
        if (!root.adapter) { root._reportError("power", "No Bluetooth adapter"); return; }
        root.adapter.enabled = enabled;
    }

    function setScanning(scanning) {
        if (!root.adapter) { root._reportError("discovery", "No Bluetooth adapter"); return; }
        root.adapter.discovering = scanning;
    }

    function setDiscoverable(discoverable) {
        if (!root.adapter) { root._reportError("discoverable", "No Bluetooth adapter"); return; }
        if (discoverable) root.adapter.pairable = true;
        root.adapter.discoverable = discoverable;
    }

    property string pendingPairId: ""

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
        device.forget();
        return true;
    }

    // Auto-connect is BlueZ's Trusted flag; the reconnect pass below acts on it.
    function setAutoConnect(id, enabled) {
        const device = root._deviceForId(id);
        if (!device) { root._reportError("set trusted", "Device is no longer available"); return false; }
        device.trusted = enabled;
        return true;
    }

    // Audio = A2DP with SBC-XQ, Call = HFP with mSBC. Each falls back to the
    // bare profile, where PipeWire picks the codec, when the device or
    // PipeWire build doesn't offer that exact one (PipeWire names the
    // best HFP codec plain "headset-head-unit", so mSBC often lives there).
    // Some headsets (JBL Tune 730BT) drop the A2DP link while in HFP, so
    // the card stops offering A2DP at all: reconnect that BlueZ profile
    // (uuid) and retry while PipeWire re-adds it.
    readonly property var audioModes: ({
        audio: { profiles: ["a2dp-sink-sbc_xq", "a2dp-sink"], uuid: "0000110b-0000-1000-8000-00805f9b34fb" },
        call: { profiles: ["headset-head-unit-msbc", "headset-head-unit"], uuid: "0000111e-0000-1000-8000-00805f9b34fb" }
    })

    function setAudioMode(address, mode) {
        const target = root.audioModes[mode];
        const device = root._deviceForId(address);
        if (!device || !target) { root._reportError("switch to " + mode, "Device is no longer available"); return false; }
        profileSetter.mode = mode;
        profileSetter.command = ["sh", "-c",
            'set_profile() { pactl set-card-profile "$1" "$2" 2>/dev/null || pactl set-card-profile "$1" "$3" 2>/dev/null; }\n'
            + 'set_profile "$1" "$2" "$3" && exit 0\n'
            + 'busctl call org.bluez "$4" org.bluez.Device1 ConnectProfile s "$5" || exit 1\n'
            + 'for i in 1 2 3 4 5; do sleep 1; set_profile "$1" "$2" "$3" && exit 0; done\n'
            + 'exit 1',
            "sh", "bluez_card." + address.replace(/:/g, "_"), target.profiles[0], target.profiles[1],
            device.dbusPath, target.uuid];
        profileSetter.run();
        return true;
    }

    property Command profileSetter: Command {
        property string mode: ""
        onFinished: result => { if (result.error) root._reportError("switch to " + mode, "Profile not available"); }
    }

    // ─── Low-battery alert ───────────────────────────────────────────────
    // "Warn only when action matters" — one alert per device per drop below
    // the threshold, not a running list. Same dedup + hysteresis shape as
    // Calendar.qml's meeting alert: fire once, and only re-fire after the
    // device has recovered well above the threshold (recharged) and dropped
    // again, so it doesn't spam every scan while just idling at 19%.
    readonly property int lowBatteryThreshold: Config.batteryAlertThreshold
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

    property Timer errorClearTimer: Timer {
        interval: 6000
        onTriggered: root.lastError = ""
    }

    // BlueZ keeps paired devices trusted but never dials out to them, so
    // audio devices stay disconnected until the host calls Connect(). At
    // startup and whenever the adapter powers on, connect every paired,
    // trusted device, retrying while the controller and devices settle.
    // Drops later in the session are left to BlueZ and the device.
    readonly property var reconnectDelays: [2000, 4000, 8000]
    property int reconnectAttempt: 0

    function _needsReconnect(device) {
        return device.paired && device.trusted && !device.connected;
    }

    function _scheduleReconnect() {
        root.reconnectAttempt = 0;
        root._armReconnect();
    }

    function _armReconnect() {
        if (!root.adapter || !root.adapter.enabled || root.reconnectAttempt >= root.reconnectDelays.length) return;
        reconnectTimer.interval = root.reconnectDelays[root.reconnectAttempt];
        reconnectTimer.restart();
    }

    property Timer reconnectTimer: Timer {
        onTriggered: {
            if (!root.adapter || !root.adapter.enabled) return;
            root.reconnectAttempt++;
            for (const device of root.nativeDevices) {
                if (root._needsReconnect(device) && device.state !== QsBluetooth.BluetoothDeviceState.Connecting)
                    device.connect();
            }
            if (root.nativeDevices.some(root._needsReconnect)) root._armReconnect();
        }
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
                    root.deviceConnectionChanged(modelData.connected);
                }
            }
        }
    }

    property Connections adapterWatcher: Connections {
        target: root.adapter
        function onEnabledChanged() {
            if (root.active && root.adapter.enabled) root.setScanning(true);
            if (root.adapter.enabled) root._scheduleReconnect();
        }
    }

    // Quickshell enumerates BlueZ once per process, so a bluetoothd that starts
    // after the shell (late boot, or a restart after a crash) is never seen and
    // the adapter stays missing. Relaunch when org.bluez gains an owner.
    property Process bluezWatcher: Process {
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("NameOwnerChanged ('org.bluez', '', ':"))
                    Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/.config/hypr/helios-reload.sh"]);
            }
        }
    }

    // The adapter can appear after startup; the first pass waits for it.
    onAdapterChanged: root._scheduleReconnect()
    Component.onCompleted: root._scheduleReconnect()
}
