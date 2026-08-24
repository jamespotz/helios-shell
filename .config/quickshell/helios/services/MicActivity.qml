pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

// True whenever any application on the system — Zoom, Discord, Teams,
// whatever — has an open capture stream against a microphone, system-wide
// and independent of which one is the default input. PipeWire keeps a
// stream node alive for the whole time an app holds the mic open, mute
// included, so this can't be fooled by a muted-but-still-capturing app the
// way watching volume/mute state alone could.
QtObject {
    id: root

    readonly property var micStreams: Pipewire.nodes
        ? Pipewire.nodes.values.filter(n => n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)
        : []

    property PwObjectTracker tracker: PwObjectTracker { objects: root.micStreams }

    readonly property bool isSystemMicActive: root.micStreams.length > 0
}
