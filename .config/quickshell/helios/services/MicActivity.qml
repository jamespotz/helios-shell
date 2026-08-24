pragma Singleton
import QtQuick
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
//
// Link lookup goes through the global Pipewire.linkGroups rather than a
// per-node PwNodeLinkTracker — verified live that PwNodeLinkTracker.linkGroups
// never populates for a tracked stream node (stays empty even for a link
// created well after the tracker existed), while Pipewire.linkGroups reflects
// reality as soon as the underlying links are tracked below.
QtObject {
    id: root

    readonly property var candidateStreams: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)
        : []

    property PwObjectTracker tracker: PwObjectTracker { objects: root.candidateStreams }
    property PwObjectTracker linkTracker: PwObjectTracker { objects: Pipewire.links.values }

    readonly property bool isSystemMicActive: {
        const candidateIds = root.candidateStreams.map(n => n.id);
        const groups = Pipewire.linkGroups.values;
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            if (g.target && candidateIds.includes(g.target.id) && g.source && !g.source.isSink)
                return true;
        }
        return false;
    }
}
