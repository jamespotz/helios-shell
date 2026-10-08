import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "modules/island" as IslandUI

ShellRoot {
    id: root
    property int phase: 0
    TestCase { id: input; name: "ShellExtensions"; when: false }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    function verify(v, message) { if (!v) throw new Error(message); }
    function find(item, text) {
        if ((item.text === text || item.label === text) && item.clicked) return item;
        for (const child of item.children || []) { const match = find(child, text); if (match) return match; }
        return null;
    }
    function press(text) {
        const button = find(surface.item, text);
        verify(button && button.enabled && button.visible, "available keyboard action: " + text);
        button.forceActiveFocus(); input.keyClick(Qt.Key_Space);
    }
    function capture(name) {
        const directory = Quickshell.env("HELIOS_EXTENSION_CAPTURE_DIR");
        if (directory) captureSurface.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"));
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 420
        implicitHeight: 760
        Rectangle {
            id: captureSurface
            anchors.fill: parent
            color: Colors.background
            IslandUI.FocusTimerWidget { id: countdown; targetScreen: ({name: "test"}); visible: FocusTimer.active; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
            Loader { id: surface; width: 380; anchors.horizontalCenter: parent.horizontalCenter; y: 20; sourceComponent: focusComponent }
        }
    }
    Component { id: focusComponent; IslandUI.FocusDestination {} }
    Component { id: cardComponent; IslandUI.FocusTimerCard {} }
    Component { id: clipboardComponent; IslandUI.ClipboardDestination {} }
    Component { id: audioComponent; IslandUI.VolumeDestination {} }
    Component { id: drivesComponent; IslandUI.DrivesDestination {} }
    Timer {
        id: advance
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            try {
                switch (phase) {
                case 0: press("25 minutes"); verify(FocusTimer.active && FocusTimer.state.presetId === "", "keyboard starts timer without preset"); break;
                case 1: verify(countdown.implicitWidth > 36 && countdown.height <= Config.idleBumpHeight && countdown.hasContent, "Idle countdown has content and width"); countdown.forceActiveFocus(); input.keyClick(Qt.Key_Space); verify(IslandNavigation.destinationId === "focus" && IslandNavigation.open, "Idle widget keyboard opens Focus"); IslandNavigation.close(); press("Pause"); capture("focus"); verify(FocusTimer.state.status === "paused", "keyboard pause"); break;
                case 2: { const before = FocusTimer.remainingMs; press("+5 minutes"); verify(FocusTimer.remainingMs === before + 300000, "keyboard extend"); press("Resume"); verify(FocusTimer.state.status === "running", "resume"); break; }
                case 3: press("Stop timer"); verify(!FocusTimer.active, "stop"); surface.sourceComponent = clipboardComponent; Clipboard.refresh(); break;
                case 4: press("Pin text"); break;
                case 5: if (Clipboard.favoriteBusy) return; verify(Clipboard.favorites.length === 1, "pin through UI"); capture("clipboard"); break;
                case 6: press("Unpin text"); break;
                case 7: if (Clipboard.favoriteBusy) return; verify(Clipboard.favorites.length === 0, "unpin through UI"); Audio.preferredOutputName = "missing-headphones"; surface.sourceComponent = audioComponent; break;
                case 8: capture("audio"); break;
                case 9: press("Clear output preference"); verify(Audio.preferredOutputName === "", "clear absent preference via keyboard"); surface.sourceComponent = drivesComponent; break;
                case 10: capture("drives"); verify(IslandNavigation.resolve("drives") !== null, "Drives registered"); verify(find(surface.item, "Refresh drives") !== null, "explicit refresh"); break;
                case 11: ShellState.setDndEnabled(true); FocusTimer.core.nowMs = Date.now(); FocusTimer.core.restore({status: "running", deadlineMs: Date.now() - 100, remainingMs: 0, presetId: "", completionPending: false}); break;
                case 12: verify(FocusTimer.completionPending && IslandNavigation.modeFor("test", false) === "focus-timer", "completion visible despite DND after save"); surface.sourceComponent = cardComponent; capture("timer-alert"); break;
                case 13: press("Dismiss timer alert"); verify(!FocusTimer.completionPending, "keyboard dismiss completion"); break;
                case 14: console.warn("SHELL_EXTENSIONS_UI_TEST_PASS"); advance.stop(); terminator.running = true; return;
                }
                phase++;
            } catch (e) { console.error("SHELL_EXTENSIONS_UI_TEST_FAIL:", e.toString()); advance.stop(); terminator.running = true; }
        }
    }
}
