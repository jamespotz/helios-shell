pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Owns Pipewire sink/source discovery and the shell's `audio` IPC surface.
QtObject {
    id: root

    // Same sink/source filtering VolumeIsland.qml uses (excludes clock-driver/
    // MIDI-bridge nodes PipeWire also reports as neither sink nor stream).
    readonly property var sinks: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && (n.type & PwNodeType.AudioSink) === PwNodeType.AudioSink) : []
    readonly property var sources: Pipewire.nodes ? Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource) : []

    property PwObjectTracker tracker: PwObjectTracker { objects: root.sinks.concat(root.sources) }

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
