import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    property real backendValue: 0.3
    property real requested: 0
    TestCase { id: input; name: "SliderDrag"; when: false }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    function verify(ok, message) { if (!ok) throw new Error(message); }
    FloatingWindow {
        visible: true
        implicitWidth: 320
        implicitHeight: 100
        Flickable {
            id: flick
            anchors.fill: parent
            contentHeight: 400
            Slider {
                id: slider
                x: 10; y: 20; width: 200
                maxValue: 1.5
                value: root.backendValue
                onMoved: v => root.requested = v
            }
        }
    }
    Timer {
        interval: 150
        running: true
        onTriggered: {
            try {
                input.mousePress(slider, 40, 12);
                input.mouseMove(slider, 120, 12);
                root.verify(Math.abs(root.requested - 0.9) < 0.01, "drag sends pointer volume");
                root.verify(Math.abs(slider.fraction - 0.6) < 0.01, "thumb follows pointer before audio reply");
                root.backendValue = 0.45;
                root.verify(Math.abs(slider.fraction - 0.6) < 0.01, "old audio reply cannot pull thumb backward");
                input.mouseRelease(slider, 120, 12);
                root.backendValue = 0.9;
                root.verify(Math.abs(slider.fraction - 0.6) < 0.01, "final audio reply displayed");
                root.backendValue = 0.6;
                root.verify(Math.abs(slider.fraction - 0.4) < 0.01, "outside changes work after drag");
                input.mousePress(slider, 80, 12);
                input.mouseMove(slider, 120, 50);
                root.verify(flick.contentY === 0, "slider keeps pointer during diagonal drag");
                input.mouseRelease(slider, 120, 50);
                console.warn("SLIDER_DRAG_TEST_PASS");
            } catch (error) {
                console.error("SLIDER_DRAG_TEST_FAIL", error.toString());
            }
            terminator.running = true;
        }
    }
}
