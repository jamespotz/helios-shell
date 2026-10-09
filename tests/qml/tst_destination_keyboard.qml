import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "services"
import "modules/island" as IslandUI

ShellRoot {
    id: root
    property int phase: 0
    property int commits: 0
    TestCase { id: input; name: "DestinationKeyboard"; when: false }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    function verify(value, message) { if (!value) throw new Error(message); }
    function press(name) {
        const control = find(surface.item, name);
        verify(control, "control exists: " + name);
        verify(control.activeFocusOnTab, "keyboard reachable: " + name);
        verify(control.Accessible.name.length > 0, "spoken name: " + name);
        commits = 0;
        control.clicked.connect(() => commits++);
        control.forceActiveFocus();
        input.keyClick(Qt.Key_Space);
        verify(commits === 1, "Space commits once: " + name);
        input.keyClick(Qt.Key_Return);
        verify(commits === 2, "Return commits once: " + name);
    }
    FloatingWindow {
        visible: true
        implicitWidth: 700
        implicitHeight: 900
        Loader { id: surface; width: 640; sourceComponent: disclosure }
    }
    Component { id: disclosure; Disclosure { title: "Test options"; Rectangle { width: 100; height: 20 } } }
    Component { id: display; IslandUI.DisplayDestination {} }
    Component { id: power; IslandUI.PowerDestination {} }
    Component { id: theme; IslandUI.ThemeDestination { themeGridOpen: true } }
    Component { id: focus; IslandUI.FocusDestination {} }
    Component { id: notifications; IslandUI.NotificationHistoryDestination {} }
    Component { id: recorder; IslandUI.ScreenRecorderDestination {} }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            try {
                switch (phase) {
                case 0: press("disclosureHeader"); verify(!surface.item.open, "disclosure reverses"); surface.sourceComponent = display; break;
                case 1: { const section = find(surface.item, "displayModes"); section.open = true; break; }
                case 2: press("displayMode"); verify(DisplaySettings.activationCount === 2, "service activates twice: displayMode"); surface.sourceComponent = power; break;
                case 3: press("powerProfile"); surface.sourceComponent = theme; break;
                case 4: press("themePreset"); verify(Themes.activationCount === 2, "service activates twice: themePreset"); surface.sourceComponent = focus; break;
                case 5: press("focusPreset"); verify(FocusModes.activationCount === 2, "service activates twice: focusPreset"); surface.sourceComponent = notifications; break;
                case 6: press("historyNotification"); verify(Notifications.activationCount === 2, "service activates twice: historyNotification"); surface.sourceComponent = recorder; break;
                case 7: press("recordCapture"); verify(ScreenRecorder.activationCount === 2, "service activates twice: recordCapture"); ScreenRecorder.starting = true;
                    const capture = find(surface.item, "recordCapture");
                    verify(!capture.enabled && !capture.activeFocusOnTab, "starting capture is disabled");
                    capture.forceActiveFocus(); input.keyClick(Qt.Key_Space);
                    verify(ScreenRecorder.activationCount === 2, "disabled capture cannot activate");
                    console.warn("DESTINATION_KEYBOARD_TEST_PASS"); terminator.running = true; stop(); return;
                }
                phase++;
            } catch (error) { console.error("DESTINATION_KEYBOARD_TEST_FAIL", error.toString()); stop(); terminator.running = true; }
        }
    }
}
