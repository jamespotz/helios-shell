import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }

    Window {
        visible: true
        width: 240
        height: 160

        SurfaceShadow {
            id: shadow
            anchors.centerIn: parent
            width: 160
            height: 80
            cornerRadius: 18
        }
    }

    Timer {
        interval: 100
        running: true
        onTriggered: {
            if (shadow.cornerRadius === 18 && shadow.glowRadius > 0)
                console.warn("SURFACE_SHADOW_TEST_PASS");
            else
                console.error("SURFACE_SHADOW_TEST_FAIL");
            root.terminator.running = true;
        }
    }
}
