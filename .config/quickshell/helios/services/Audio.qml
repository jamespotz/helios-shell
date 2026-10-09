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
    property Process bluetoothKeepalive: Process {
        command: ["python3", Qt.resolvedUrl("bluetooth-audio-keepalive.py").toString().replace("file://", "")]
        running: Config.interfaceSounds && root.interactionOpen
    }

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
    function isBluetoothSink(node) {
        const props = node.properties || {};
        return !!props["api.bluez5.address"] || props["device.api"] === "bluez5" || props["device.bus"] === "bluetooth" || String(node.name).startsWith("bluez_output.");
    }
    // Bluetooth's connection rule owns routing across A2DP/HFP node recreation.
    function routeConnectedBluetoothOutput(name) {
        if (outputRule.canRouteConnection(name, root._pipewireReady)) root.setOutput(name);
    }
    function _updateOutputs() {
        const arrived = outputRule.update(root._sinkNames, root._pipewireReady);
        const node = root.sinks.find(candidate => candidate.name === arrived);
        if (node && !root.isBluetoothSink(node)) Pipewire.preferredDefaultAudioSink = node;
    }
    on_SinkNamesChanged: root._updateOutputs()
    on_PipewireReadyChanged: root._updateOutputs()
    Component.onCompleted: { outputPreferenceFile.text(); root._updateOutputs(); }

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
