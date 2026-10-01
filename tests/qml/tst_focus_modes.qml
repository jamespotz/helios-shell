import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    Component.onCompleted: {
        try {
            const before = FocusModes.presets.length;
            const preset = FocusModes.addPreset();
            root.verify(FocusModes.presets.length === before + 1 && preset.dnd, "add preset");
            FocusModes.updatePreset(preset.id, { name: "Deep Work", caffeine: true });
            const updated = FocusModes.presets.find(p => p.id === preset.id);
            root.verify(updated.name === "Deep Work" && updated.caffeine && updated.dnd, "update merges patch");
            FocusModes.activeId = preset.id;
            FocusModes.removePreset(preset.id);
            root.verify(FocusModes.presets.length === before && FocusModes.activeId === "", "remove clears active preset");
            console.warn("FOCUS_MODES_TEST_PASS");
        } catch (error) {
            console.error("FOCUS_MODES_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
