pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Owns Pipewire sink/source discovery and the shell's `audio` IPC surface.
QtObject {
    id: root

    // Same sink/source filtering VolumeDestination.qml uses (excludes clock-driver/
    // MIDI-bridge nodes PipeWire also reports as neither sink nor stream).
    readonly property var sinks: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink) : []
    readonly property var sources: Pipewire.nodes ? Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource) : []

    property PwObjectTracker tracker: PwObjectTracker { objects: root.sinks.concat(root.sources) }

    // Each Island owns its entry, so closing one screen cannot release another.
    property var expandedIslandScreens: ({})
    function setIslandExpanded(screenName, expanded) {
        const next = Object.assign({}, root.expandedIslandScreens);
        if (expanded) next[screenName] = true;
        else delete next[screenName];
        root.expandedIslandScreens = next;
    }
    readonly property bool interactionOpen: Object.keys(root.expandedIslandScreens).length > 0
        || IslandNavigation.open || IslandNavigation.satelliteOpen || ShellState.settingsOpen
    // Idle outputs delay or clip the first sound, so a silent stream keeps
    // the default sink awake while interface sounds are on. Wired outputs
    // stay awake throughout; Bluetooth only during an interaction, since a
    // constant stream holds the headset's radio and drains its battery.
    readonly property bool bluetoothOutput: !!Pipewire.defaultAudioSink && root.isBluetoothSink(Pipewire.defaultAudioSink)
    property Process audioKeepalive: Process {
        command: ["python3", Qt.resolvedUrl("audio-keepalive.py").toString().replace("file://", "")]
        running: Config.interfaceSounds && (!root.bluetoothOutput || root.interactionOpen)
    }

    // Quickshell's Pipewire service has no "move this stream" call, so this
    // shells out to pactl. pactl's sink-input and sink indexes equal
    // PipeWire's object.serial, not object.id (node.id), so read the serial.
    function moveStream(stream, sink) {
        const from = stream.properties ? stream.properties["object.serial"] : null;
        const to = sink.properties ? sink.properties["object.serial"] : null;
        if (!from || !to) return;
        streamMover.command = ["pactl", "move-sink-input", String(from), String(to)];
        streamMover.running = false;
        streamMover.running = true;
    }
    property Process streamMover: Process {}

    property string preferredOutputName: ""
    property string error: ""
    readonly property bool _pipewireReady: Pipewire.ready
    readonly property var _sinkNames: root.sinks.map(node => node.name)
    property AudioOutputRuleCore outputRule: AudioOutputRuleCore { preferredName: root.preferredOutputName }
    property FileView outputPreferenceFile: FileView {
        path: Quickshell.statePath("audio-output-preference.json")
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try { const saved = JSON.parse(text()); if (typeof saved.name === "string") root.preferredOutputName = saved.name; } catch (e) { }
        }
        onSaveFailed: root.error = qsTr("Could not save the audio preference")
        onSaved: root.error = ""
    }
    function preferOutput(name) {
        root.preferredOutputName = name;
        outputPreferenceFile.setText(JSON.stringify({ name: name }));
        const selected = root.sinks.find(node => node.name === name);
        outputRule.seed(root._sinkNames);
        if (selected) Pipewire.preferredDefaultAudioSink = selected;
    }
    function clearOutputPreference() { root.preferOutput(""); }
    function isBluetoothSink(node) { return outputRule.isBluetoothSink(node.name, node.properties); }

    // ─── Bluetooth reconnects → restore the preferred output ─────
    // See AudioOutputRuleCore.bluetoothStep.
    readonly property var _connectedBluetoothIds: Bluetooth.state.devices
        .filter(device => device.connected)
        .map(device => device.id)
    readonly property var _connectedBluetoothAudio: Bluetooth.state.devices
        .filter(device => device.connected && device.audio && device.audio.nodeName)
        .map(device => ({ id: device.id, nodeName: device.audio.nodeName }))
    property var _bluetoothState: null
    function _updateBluetooth() {
        // Devices already connected at startup aren't reconnects.
        if (!root._bluetoothState) {
            root._bluetoothState = { connected: root._connectedBluetoothIds, pending: [] };
            return;
        }
        const step = outputRule.bluetoothStep(root._bluetoothState, root._connectedBluetoothIds, root._connectedBluetoothAudio);
        root._bluetoothState = step.state;
        if (step.route && root.preferredOutputName === step.route
                && outputRule.canRouteConnection(step.route, root._pipewireReady)) root.setOutput(step.route);
    }
    on_ConnectedBluetoothIdsChanged: root._updateBluetooth()
    on_ConnectedBluetoothAudioChanged: root._updateBluetooth()

    function _updateOutputs() {
        const arrived = outputRule.update(root._sinkNames, root._pipewireReady);
        const node = root.sinks.find(candidate => candidate.name === arrived);
        if (node && !root.isBluetoothSink(node)) Pipewire.preferredDefaultAudioSink = node;
    }
    on_SinkNamesChanged: root._updateOutputs()
    on_PipewireReadyChanged: root._updateOutputs()
    Component.onCompleted: { outputPreferenceFile.text(); root._updateOutputs(); root._updateBluetooth(); }

    // Matches against node.name first (stable pipewire id), falling back to
    // a case-insensitive substring match on description/nickname — e.g.
    // `audio setOutput "USB Headset"`.
    function findNode(nodes, match) {
        const needle = match.toLowerCase();
        return nodes.find(n => n.name === match)
            || nodes.find(n => String(n.description || "").toLowerCase().includes(needle) || String(n.nickname || "").toLowerCase().includes(needle));
    }

    function setOutput(match) {
        const node = root.findNode(root.sinks, match);
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setInput(match) {
        const node = root.findNode(root.sources, match);
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }
}
