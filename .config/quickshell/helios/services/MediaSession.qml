pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: root

    readonly property MediaSessionCore _core: MediaSessionCore {
        players: Mpris.players ? Mpris.players.values : []
    }
    readonly property var state: root._core.state

    function selectPlayer(id) { return root._core.selectPlayer(id); }
    function seek(fraction) { return root._core.seek(fraction); }
    function previous() { return root._core.previous(); }
    function togglePlaying() { return root._core.togglePlaying(); }
    function next() { return root._core.next(); }
    function toggleShuffle() { return root._core.toggleShuffle(); }
    function cycleLoop() { return root._core.cycleLoop(); }
}
