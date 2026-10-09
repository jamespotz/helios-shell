import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "modules/island" as IslandUI

ShellRoot {
    id: root
    property int phase: 0
    TestCase { id: input; name: "LinkSounds"; when: false }
    property FileView calls: FileView { path: Quickshell.env("HELIOS_SOUND_CALLS"); blockLoading: true }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    function verify(ok, message) { if (!ok) throw new Error(message); }
    function find(item, predicate) {
        if (predicate(item)) return item;
        for (const child of item.children || []) { const result = find(child, predicate); if (result) return result; }
        return null;
    }
    function textAction(item, text) {
        const label = find(item, child => child.text === text && child.icon === undefined);
        verify(label, "action exists: " + text);
        return label.parent.parent;
    }
    function pointerCommit(item) {
        const area = find(item, child => child.cursorShape === Qt.PointingHandCursor && child.clicked);
        verify(area, "pointer action exists");
        area.clicked(null);
    }
    FloatingWindow {
        visible: true
        implicitWidth: 720
        implicitHeight: 700
        IslandUI.CalendarDestination { id: calendar; width: 640; selectedDate: new Date(2026, 8, 3); viewDate: selectedDate }
        IslandUI.BluetoothDestination { id: bluetooth; visible: false }
        IslandUI.WifiDestination { id: wifi; visible: false }
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            try {
                if (phase === 0) {
                    Calendar._completeRefresh({ events: [{summary: "Planning", date: "2026-09-03", allDay: true,
                        startTime: "", endTime: "", source: "Work", links: [{url: "https://example.com/meeting", label: "Join meeting"}]}], subscriptionErrors: [] });
                    // Interface sounds off: explicit scan commits stay silent.
                    pointerCommit(textAction(bluetooth, "Scan"));
                    verify(Bluetooth.scanning, "Bluetooth scan starts");
                    verify(textAction(bluetooth, "Stop Scan").enabled, "Bluetooth stop remains available");
                    pointerCommit(textAction(wifi, WifiNetworks.scanning ? "Stop Scan" : "Scan"));
                    phase++;
                    return;
                }
                if (phase === 1) {
                    calls.reload();
                    verify(!calls.text().includes("play-sample"), "disabled interface sounds stay silent");
                    Config.setOption("interfaceSounds", true);
                    pointerCommit(textAction(bluetooth, "Stop Scan"));
                    verify(!Bluetooth.scanning, "second Bluetooth commit stops discovery");
                    verify(textAction(bluetooth, "Scan"), "Bluetooth label returns to Scan");
                    bluetooth.visible = true;
                    const discoverable = textAction(bluetooth, "Make Discoverable");
                    discoverable.forceActiveFocus(); input.keyClick(Qt.Key_Return);
                    verify(Bluetooth.discoverable, "keyboard commit makes Bluetooth discoverable");
                    bluetooth.visible = false;
                    pointerCommit(textAction(wifi, WifiNetworks.scanning ? "Stop Scan" : "Scan"));
                    const disclosure = textAction(calendar, "link");
                    disclosure.forceActiveFocus(); input.keyClick(Qt.Key_Space);
                    phase++;
                    return;
                }
                if (phase === 2) {
                    const link = find(calendar, item => item.modelData && item.modelData.url === "https://example.com/meeting");
                    verify(link, "disclosure opens calendar link");
                    link.forceActiveFocus(); input.keyClick(Qt.Key_Return);
                    const day = find(calendar, item => item.cellDate && item.modelData === 4);
                    verify(day, "calendar day exists");
                    pointerCommit(day);
                    verify(calendar.selectedDate.getDate() === 4, "day commit selects date");
                    phase++;
                    return;
                }
                if (phase === 3) {
                    calls.reload();
                    phase++;
                    return;
                }
                const plays = calls.text().trim().split("\n").filter(line => line === "play-sample helios-tap");
                verify(plays.length === 6, "six commits each tap once, got " + plays.length + " calls=" + calls.text() + " enabled=" + Config.interfaceSounds);
                verify(calls.text().includes("https://example.com/meeting"), "link still opens URL");
                console.warn("LINK_SOUNDS_TEST_PASS");
            } catch (error) {
                console.error("LINK_SOUNDS_TEST_FAIL", error.toString());
            }
            terminator.running = true;
        }
    }
}
