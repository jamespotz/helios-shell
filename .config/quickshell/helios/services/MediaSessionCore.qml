import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: root

    required property var players
    property string selectedId: ""
    property real position: root.player ? root.player.position : 0

    readonly property var player: root._selectPlayer(root.players, root.selectedId)
    readonly property var state: ({
        players: (root.players || []).map(p => ({ id: p.dbusName, name: p.identity || "Player" })),
        selectedId: root.player ? root.player.dbusName : "",
        track: root.player ? ({
            title: root.player.trackTitle || "",
            artist: root.player.trackArtist || "",
            artUrl: root.player.trackArtUrl || "",
            duration: root.player.length || 0,
            position: root.position
        }) : null,
        playback: root.player ? ({
            playing: !!root.player.isPlaying,
            shuffle: !!root.player.shuffle,
            loop: root.player.loopState === MprisLoopState.Track ? "track"
                : root.player.loopState === MprisLoopState.Playlist ? "playlist" : "none"
        }) : ({ playing: false, shuffle: false, loop: "none" }),
        capabilities: root.player ? ({
            seek: !!root.player.canSeek,
            previous: !!root.player.canGoPrevious,
            toggle: !!root.player.canTogglePlaying,
            next: !!root.player.canGoNext,
            shuffle: !!root.player.shuffleSupported,
            loop: !!root.player.loopSupported
        }) : ({ seek: false, previous: false, toggle: false, next: false, shuffle: false, loop: false }),
        identity: root.player ? root.player.identity || "" : ""
    })

    onPlayersChanged: {
        if (root.selectedId && !(root.players || []).some(p => p.dbusName === root.selectedId))
            root.selectedId = "";
        root.position = root.player ? root.player.position : 0;
    }
    onPlayerChanged: root.position = root.player ? root.player.position : 0

    function _selectPlayer(list, selectedId) {
        const candidates = list || [];
        if (selectedId) {
            const selected = candidates.find(p => p.dbusName === selectedId);
            if (selected) return selected;
        }
        return candidates.find(p => p.isPlaying) || candidates.find(p => p.canControl) || candidates[0] || null;
    }

    function selectPlayer(id) {
        if (!(root.players || []).some(p => p.dbusName === id)) return false;
        root.selectedId = id;
        return true;
    }

    function seek(fraction) {
        if (!root.player || !root.player.canSeek || root.player.length <= 0) return false;
        const next = Math.max(0, Math.min(1, fraction)) * root.player.length;
        root.player.position = next;
        root.position = next;
        return true;
    }

    function previous() {
        if (!root.player || !root.player.canGoPrevious) return false;
        root.player.previous();
        return true;
    }

    function togglePlaying() {
        if (!root.player || !root.player.canTogglePlaying) return false;
        root.player.togglePlaying();
        return true;
    }

    function next() {
        if (!root.player || !root.player.canGoNext) return false;
        root.player.next();
        return true;
    }

    function toggleShuffle() {
        if (!root.player || !root.player.shuffleSupported) return false;
        root.player.shuffle = !root.player.shuffle;
        return true;
    }

    function cycleLoop() {
        if (!root.player || !root.player.loopSupported) return false;
        if (root.player.loopState === MprisLoopState.None) root.player.loopState = MprisLoopState.Playlist;
        else if (root.player.loopState === MprisLoopState.Playlist) root.player.loopState = MprisLoopState.Track;
        else root.player.loopState = MprisLoopState.None;
        return true;
    }

    property Timer positionTimer: Timer {
        interval: 1000
        running: !!(root.player && root.player.isPlaying)
        repeat: true
        onTriggered: root.position = root.player.position
    }

    property Connections playerConnections: Connections {
        target: root.player && root.player.positionChanged ? root.player : null
        function onPositionChanged() { root.position = root.player ? root.player.position : 0; }
        function onTrackTitleChanged() { root.position = root.player ? root.player.position : 0; }
    }
}
