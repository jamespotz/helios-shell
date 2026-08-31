import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import services

ShellRoot {
    id: root

    readonly property Process _terminator: Process {
        command: ["sh", "-c", 'kill -TERM "$PPID"']
    }
    readonly property Timer _terminateDelay: Timer {
        interval: 50
        onTriggered: root._terminator.running = true
    }

    function fail(message) { throw new Error(message); }
    function verify(value, message) { if (!value) root.fail(message || "verification failed"); }
    function compare(actual, expected, message) {
        if (actual !== expected) root.fail((message || "values differ") + `: expected ${expected}, got ${actual}`);
    }
    function pass() {
        console.warn("MPRIS_HELPERS_TEST_PASS");
        root._terminateDelay.start();
    }
    function reportFailure(error) {
        console.error("MPRIS_HELPERS_TEST_FAIL:", error.toString());
        root._terminateDelay.start();
    }

    function test_selectPlayerReturnsNullForEmptyList() {
        root.compare(MprisHelpers.selectPlayer([], ""), null);
    }

    function test_selectPlayerPrefersPinnedSelection() {
        const players = [
            { dbusName: "a", isPlaying: false, canControl: true },
            { dbusName: "b", isPlaying: true, canControl: true }
        ];
        // "b" is playing, but "a" is explicitly pinned — pinned wins.
        root.compare(MprisHelpers.selectPlayer(players, "a").dbusName, "a");
    }

    function test_selectPlayerFallsBackWhenPinnedIsGone() {
        const players = [
            { dbusName: "a", isPlaying: false, canControl: true },
            { dbusName: "b", isPlaying: true, canControl: true }
        ];
        // "missing" no longer exists — falls back to the playing one.
        root.compare(MprisHelpers.selectPlayer(players, "missing").dbusName, "b");
    }

    function test_selectPlayerPrefersPlayingOverFirstControllable() {
        const players = [
            { dbusName: "a", isPlaying: false, canControl: true },
            { dbusName: "b", isPlaying: true, canControl: true }
        ];
        root.compare(MprisHelpers.selectPlayer(players, "").dbusName, "b");
    }

    function test_nextLoopStateCyclesNoneToPlaylistToTrackToNone() {
        root.compare(MprisHelpers.nextLoopState(MprisLoopState.None), MprisLoopState.Playlist);
        root.compare(MprisHelpers.nextLoopState(MprisLoopState.Playlist), MprisLoopState.Track);
        root.compare(MprisHelpers.nextLoopState(MprisLoopState.Track), MprisLoopState.None);
    }

    Component.onCompleted: {
        try {
            root.test_selectPlayerReturnsNullForEmptyList();
            root.test_selectPlayerPrefersPinnedSelection();
            root.test_selectPlayerFallsBackWhenPinnedIsGone();
            root.test_selectPlayerPrefersPlayingOverFirstControllable();
            root.test_nextLoopStateCyclesNoneToPlaylistToTrackToNone();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
