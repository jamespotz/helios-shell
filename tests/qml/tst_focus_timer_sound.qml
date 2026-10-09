import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    id: root
    property var sounds: AlertSounds
    property FileView calls: FileView { path: Quickshell.env("HELIOS_SOUND_CALLS"); blockLoading: true }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    Timer {
        interval: 150
        running: true
        onTriggered: {
            Config.setOption("alertSounds", false);
            FocusTimer.start(0.001, "");
            finish.start();
        }
    }
    Timer {
        id: finish
        interval: 150
        onTriggered: {
            FocusTimer.updateTime();
            FocusTimer.updateTime();
            check.start();
        }
    }
    Timer {
        id: check
        interval: 150
        onTriggered: {
            calls.reload();
            if (FocusTimer.completionPending && calls.text().trim() === "--id=bell")
                console.warn("FOCUS_TIMER_SOUND_TEST_PASS");
            else console.error("FOCUS_TIMER_SOUND_TEST_FAIL", calls.text());
            terminator.running = true;
        }
    }
}
