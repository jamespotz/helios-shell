pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell.Services.Pipewire

// True whenever any application on the system — Zoom, Discord, Teams,
// whatever — has an open capture stream against a real microphone,
// system-wide and independent of which one is the default input.
// PipeWire keeps a stream node alive for the whole time an app holds the
// mic open, mute included, so this can't be fooled by a muted-but-still-
// capturing app the way watching volume/mute state alone could.
//
// A stream capturing a sink's monitor (system audio — e.g. cava, or a
// screen recorder grabbing system audio) matches the same
// isStream/AudioSource filter as a real mic capture, so each candidate
// stream's upstream link is checked too: only a link whose source is an
// actual capture device (not a Sink, i.e. not a monitor) counts.
QtObject {
    id: root

    readonly property var candidateStreams: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)
        : []

    property PwObjectTracker tracker: PwObjectTracker { objects: root.candidateStreams }

    property Instantiator linkTrackers: Instantiator {
        model: root.candidateStreams
        delegate: PwNodeLinkTracker { node: modelData }
    }

    readonly property bool isSystemMicActive: {
        for (let i = 0; i < root.linkTrackers.count; i++) {
            const groups = root.linkTrackers.objectAt(i).linkGroups;
            for (let j = 0; j < groups.length; j++) {
                if (groups[j].source && !groups[j].source.isSink)
                    return true;
            }
        }
        return false;
    }
}
