import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import services
import "modules/bar" as BarModules

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }

    Window {
        visible: true
        width: 600
        height: 520

        BarModules.LauncherIsland {
            id: launcher
            anchors.centerIn: parent
        }

        Item { id: focusStealer; focus: false }
    }

    Timer {
        interval: 80
        running: true
        onTriggered: focusStealer.forceActiveFocus()
    }

    Timer {
        interval: 220
        running: true
        onTriggered: {
            if (launcher.searchFocused) console.warn("LAUNCHER_FOCUS_TEST_PASS");
            else console.error("LAUNCHER_FOCUS_TEST_FAIL: search input lost focus after window focus handoff");
            root.terminator.running = true;
        }
    }
}
