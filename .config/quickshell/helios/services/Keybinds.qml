pragma Singleton
import QtQuick
import Quickshell.Io

// Hyprland's described keybinds, read from `hyprctl binds -j`. Undescribed
// binds are internal plumbing and stay out of the cheatsheet.
QtObject {
    id: root

    property var entries: []

    function refresh() {
        bindsProc.running = false;
        bindsProc.running = true;
    }

    property Process bindsProc: Process {
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.entries = JSON.parse(text).filter(b => b.description && b.description.length > 0);
                } catch (e) {
                    root.entries = [];
                }
            }
        }
    }
}
