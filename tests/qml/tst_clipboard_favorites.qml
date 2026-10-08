import QtQuick
import Quickshell
import Quickshell.Io
import services
ShellRoot {
    id: root
    property int stage: 0
    property string payload: "first line\nquotes ' \" and $(touch /tmp/helios-should-not-exist)\n\n"
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    FileView { id: copied; path: Quickshell.env("HELIOS_CLIP_TEST") + "/copied"; blockLoading: true; printErrors: false }
    FileView { id: failCopy; path: Quickshell.env("HELIOS_CLIP_TEST") + "/fail-copy"; blockWrites: true; printErrors: false }
    function verify(v, message) { if (!v) throw new Error(message); }
    property Timer runner: Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (Clipboard.favoriteBusy) return;
            try {
                if (stage === 0) { Clipboard.pin("1\tfirst line"); stage++; }
                else if (stage === 1) { verify(Clipboard.favorites.length === 1 && Clipboard.favorites[0].text === payload, "preserve full text and trailing newlines"); Clipboard.pin("2\tfirst line"); stage++; }
                else if (stage === 2) { verify(Clipboard.favorites.length === 1, "deduplicate decoded text"); Clipboard.copyFavorite(Clipboard.favorites[0].id); stage++; }
                else if (stage === 3) { copied.reload(); verify(copied.text() === payload, "copy exact literal payload"); Clipboard.clearAll(); Clipboard.remove("1\tfirst line"); Clipboard.favoritesFile.reload(); stage++; }
                else if (stage === 4) { verify(Clipboard.favorites.length === 1, "wipe and reload preserve favorites"); Clipboard.pin("bad\tbroken"); stage++; }
                else if (stage === 5) { verify(Clipboard.error.length > 0 && Clipboard.favorites.length === 1, "decode failure preserves favorites"); failCopy.setText("fail"); Clipboard.copyFavorite(Clipboard.favorites[0].id); stage++; }
                else if (stage === 6) { verify(Clipboard.error.length > 0 && Clipboard.favorites.length === 1, "copy failure visible"); Clipboard.unpin(Clipboard.favorites[0].id); stage++; }
                else if (stage === 7) { verify(Clipboard.favorites.length === 0, "unpin"); verify(!Clipboard.pin("3\t[[ binary data 10 KiB png ]]") && Clipboard.error.length > 0, "reject images"); Clipboard.pin("4\tfirst line"); stage++; }
                else if (stage === 8) { verify(Clipboard.favorites.length === 1, "repin"); Clipboard.favoritesFile.path = Quickshell.env("HELIOS_CLIP_TEST"); Clipboard.unpin(Clipboard.favorites[0].id); stage++; }
                else { verify(Clipboard.favorites.length === 1 && Clipboard.error.length > 0, "save failure preserves favorites"); console.warn("CLIPBOARD_FAVORITES_TEST_PASS"); runner.stop(); terminator.running = true; }
            } catch (e) { console.error("CLIPBOARD_FAVORITES_TEST_FAIL:", e.toString()); runner.stop(); terminator.running = true; }
        }
    }
}
