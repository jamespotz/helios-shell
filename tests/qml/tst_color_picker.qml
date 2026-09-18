import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    id: root

    property bool chosen: false
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }

    Window {
        visible: true
        width: 240
        height: 360

        ColorPicker {
            id: picker
            onColorChosen: color => {
                root.chosen = color.toString() === "#e5484d";
                resultDelay.start();
            }
        }
    }

    Timer {
        interval: 100
        running: true
        onTriggered: picker._pickFromScreen()
    }

    Timer {
        id: resultDelay
        interval: 50
        onTriggered: {
            if (root.chosen)
                console.warn("COLOR_PICKER_TEST_PASS");
            else
                console.error("COLOR_PICKER_TEST_FAIL");
            root.terminator.running = true;
        }
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: {
            console.error("COLOR_PICKER_TEST_FAIL timed out");
            root.terminator.running = true;
        }
    }
}
