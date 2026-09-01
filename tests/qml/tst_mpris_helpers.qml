import QtQuick
import Quickshell
import Quickshell.Io
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

    MediaSessionCore { id: session; players: [] }

    function player(id, playing, controllable) {
        return {
            dbusName: id, identity: id.toUpperCase(), isPlaying: playing, canControl: controllable,
            position: 0, length: 100, trackTitle: id, trackArtist: "artist", trackArtUrl: "",
            canSeek: true, canGoPrevious: true, canTogglePlaying: true, canGoNext: true,
            shuffleSupported: true, shuffle: false, loopSupported: false, loopState: 0,
            previous: function() {}, togglePlaying: function() {}, next: function() {}
        };
    }

    function test_emptySessionHasCoherentState() {
        session.players = [];
        root.compare(session.state.selectedId, "");
        root.compare(session.state.track, null);
        root.verify(!session.state.capabilities.seek);
    }

    function test_selectPlayerPrefersPinnedSelection() {
        session.players = [root.player("a", false, true), root.player("b", true, true)];
        root.verify(session.selectPlayer("a"));
        root.compare(session.state.selectedId, "a");
    }

    function test_selectPlayerFallsBackWhenPinnedIsGone() {
        session.selectedId = "missing";
        session.players = [root.player("a", false, true), root.player("b", true, true)];
        root.compare(session.state.selectedId, "b");
    }

    function test_selectPlayerPrefersPlayingOverFirstControllable() {
        session.selectedId = "";
        session.players = [root.player("a", false, true), root.player("b", true, true)];
        root.compare(session.state.selectedId, "b");
    }

    function test_seekIsOwnedBySession() {
        const p = root.player("a", true, true);
        session.players = [p];
        root.verify(session.seek(0.25));
        root.compare(p.position, 25);
        root.compare(session.state.track.position, 25);
    }

    Component.onCompleted: {
        try {
            root.test_emptySessionHasCoherentState();
            root.test_selectPlayerPrefersPinnedSelection();
            root.test_selectPlayerFallsBackWhenPinnedIsGone();
            root.test_selectPlayerPrefersPlayingOverFirstControllable();
            root.test_seekIsOwnedBySession();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
