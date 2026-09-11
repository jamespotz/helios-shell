import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "modules/bar" as BarModules

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }

    Window {
        visible: true
        width: 600
        height: 520

        BarModules.KeybindsIsland {
            id: keybinds
            anchors.centerIn: parent
        }
    }

    Timer {
        interval: 120
        running: true
        onTriggered: {
            keybinds.entries = [
                { description: "First", modmask: 64, key: "A" },
                { description: "Second", modmask: 64, key: "B" },
                { description: "Third", modmask: 64, key: "C" }
            ];
            keybinds.moveSelection(1);
            keybinds.moveSelection(1);
            keybinds.moveSelection(-1);

            if (keybinds.selectedIndex === 1) console.warn("KEYBINDS_NAVIGATION_TEST_PASS");
            else console.error("KEYBINDS_NAVIGATION_TEST_FAIL: expected index 1, got " + keybinds.selectedIndex);
            root.terminator.running = true;
        }
    }
}
