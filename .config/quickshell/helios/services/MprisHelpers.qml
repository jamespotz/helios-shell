pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

// Pure Mpris selection/state-transition helpers, split out of MediaCard.qml
// so they're unit-testable without a live D-Bus session or real players.
QtObject {
    id: root

    function selectPlayer(players, selectedId) {
        const list = players || [];
        if (selectedId) {
            const selected = list.find(p => p.dbusName === selectedId);
            if (selected) return selected;
        }
        return list.find(p => p.isPlaying) || list.find(p => p.canControl) || list[0] || null;
    }

    function nextLoopState(current) {
        if (current === MprisLoopState.None) return MprisLoopState.Playlist;
        if (current === MprisLoopState.Playlist) return MprisLoopState.Track;
        return MprisLoopState.None;
    }
}
