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
    function fieldInput(item, name) {
        if (item.objectName === name) return item.children[1].children[0];
        for (const child of item.children || []) { const match = fieldInput(child, name); if (match) return match; }
        return null;
    }
    function enterMinutes(name, value) {
        const field = fieldInput(surface.item, name);
        verify(field !== null, "custom duration field exists");
        field.forceActiveFocus(); input.keyClick(Qt.Key_A, Qt.ControlModifier); for (const digit of String(value)) input.keyClick(Qt.Key_0 + Number(digit)); input.keyClick(Qt.Key_Tab);
    }
    function hasText(item, text) {
        if (item.text === text) return true;
        return (item.children || []).some(child => hasText(child, text));
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
            Item { id: satelliteAnchor; x: 180; y: 700; width: 140; height: 32 }
            IslandUI.IslandSatelliteHost { id: countdown; anchorItem: satelliteAnchor; targetScreen: "test"; definition: IslandNavigation.satelliteFor("test", false) }
            Loader { id: surface; width: 380; anchors.horizontalCenter: parent.horizontalCenter; y: 20; sourceComponent: focusComponent }
        }
    }
    Component { id: focusComponent; IslandUI.FocusDestination {} }
    Component { id: timerComponent; IslandUI.IslandDestinationHost { destinationId: "focus-timer"; targetScreen: "test" } }
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
                case 0: press("25 minutes"); press("Start focus"); verify(FocusTimer.active && FocusTimer.state.presetId === "", "keyboard starts timer without preset"); break;
                case 1: verify(countdown.active && !countdown.onRight && countdown.activityId === "focus-timer" && countdown.width > Config.satelliteBadgeSize, "countdown uses a wide left Satellite"); countdown.clicked(); verify(IslandNavigation.panelOpenFor("test") && IslandNavigation.destinationId === "focus-timer" && !IslandNavigation.satelliteOpen, "countdown opens timer in main Island"); surface.sourceComponent = timerComponent; press("Pause"); capture("focus"); verify(FocusTimer.state.status === "paused", "keyboard pause"); break;
                case 2: { verify(!countdown.expanded && find(countdown, "Stop timer") === null && find(surface.item, "Stop timer") !== null, "timer controls load in Island while countdown stays compact"); IslandNavigation.close(); const before = FocusTimer.remainingMs; press("+5 minutes"); verify(FocusTimer.remainingMs === before + 300000, "keyboard extend"); press("Resume"); verify(FocusTimer.state.status === "running", "resume"); break; }
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
                case 14: surface.sourceComponent = focusComponent; capture("custom-form"); break;
                case 15: verify(find(surface.item, "Short break · 5m") === null && find(surface.item, "Long break · 15m") === null, "standalone break buttons removed"); enterMinutes("customFocusMinutes", 35); enterMinutes("customBreakMinutes", 0); verify(!find(surface.item, "Start focus").enabled, "invalid custom duration disables start"); enterMinutes("customBreakMinutes", 12); press("Start focus"); verify(FocusTimer.state.nextBreak === 12, "custom focus schedules chosen break"); FocusTimer.core.nowMs = FocusTimer.state.deadlineMs; FocusTimer.core.tick(); verify(FocusTimer.state.kind === "custom-break", "custom focus automatically starts break"); capture("custom-break"); break;
                case 16: FocusTimer.core.nowMs = FocusTimer.state.deadlineMs; FocusTimer.core.tick(); surface.sourceComponent = cardComponent; break;
                case 17: verify(FocusTimer.completionPending && hasText(surface.item, "Break complete"), "break completion alert"); capture("break-alert"); break;
                case 18: verify(find(surface.item, "Short break · 5m") === null && find(surface.item, "Long break · 15m") === null, "completion break buttons removed"); press("Dismiss timer alert"); break;
                case 19: surface.sourceComponent = focusComponent; break;
                case 20: press("90 minutes"); press("Start focus"); verify(FocusTimer.state.nextBreak === 20, "90 minute button schedules extended break"); break;
                case 21: FocusTimer.core.nowMs = FocusTimer.state.deadlineMs; FocusTimer.core.tick(); verify(FocusTimer.state.kind === "custom-break" && FocusTimer.remainingMs === 1200000, "90 minute session starts 20 minute break"); FocusTimer.stop(); break;
                case 22: console.warn("SHELL_EXTENSIONS_UI_TEST_PASS"); advance.stop(); terminator.running = true; return;
                }
                phase++;
            } catch (e) { console.error("SHELL_EXTENSIONS_UI_TEST_FAIL:", e.toString()); advance.stop(); terminator.running = true; }
        }
    }
}
