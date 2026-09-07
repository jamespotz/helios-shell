pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// Webcam counterpart to MicActivity.qml — same technique, VideoSource
// streams instead of AudioSource ones. Any app with an open capture
// against a real camera (Zoom, a browser tab, Cheese, whatever) keeps a
// PipeWire stream node alive for as long as the capture is open.
QtObject {
    id: root

    readonly property var candidateStreams: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isStream && (n.type & PwNodeType.VideoSource) === PwNodeType.VideoSource)
        : []

    property PwObjectTracker tracker: PwObjectTracker { objects: root.candidateStreams }
    property PwObjectTracker linkTracker: PwObjectTracker { objects: Pipewire.links.values }

    readonly property var _activeIds: {
        const candidateIds = root.candidateStreams.map(n => n.id);
        const groups = Pipewire.linkGroups.values;
        const ids = new Set();
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            if (g.target && candidateIds.includes(g.target.id) && g.source && !g.source.isSink)
                ids.add(g.target.id);
        }
        return ids;
    }

    readonly property bool isSystemCameraActive: root._activeIds.size > 0

    readonly property var activeApps: root.candidateStreams
        .filter(n => root._activeIds.has(n.id))
        .map(n => (n.properties && n.properties["application.name"]) || n.description || n.name)
}
