pragma Singleton
import QtQuick
import Quickshell.Io

// Hyprland's described keybinds, read from `hyprctl binds -j`. Undescribed
// binds are internal plumbing and stay out of the cheatsheet.
QtObject {
    id: root

    property var entries: []
    // Every bind, described or not — for checking a new combo is free.
    property var all: []

    function refresh() {
        bindsProc.running = false;
        bindsProc.running = true;
    }

    property Process bindsProc: Process {
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.all = JSON.parse(text);
                    root.entries = root.all.filter(b => b.description && b.description.length > 0);
                } catch (e) {
                    root.all = [];
                    root.entries = [];
                }
            }
        }
    }
}
