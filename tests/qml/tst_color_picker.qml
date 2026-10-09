import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    id: root

    property bool chosen: false
    property bool samplingScreen: false
    TestCase { id: input; name: "ColorPickerInputs"; when: false }
    function findHex(item) {
        if (item.editingFinished && item.selectByMouse !== undefined) return item;
        for (const child of item.children || []) { const found = findHex(child); if (found) return found; }
        return null;
    }
    function findSwatch(item) {
        if (item.width === 22 && item.color !== undefined && item.color.toString() === "#00ff00") return item;
        for (const child of item.children || []) { const found = findSwatch(child); if (found) return found; }
        return null;
    }
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }

    Window {
        visible: true
        width: 240
        height: 360

        ColorPicker {
            id: picker
            recentColors: ["#00ff00"]
            onColorChosen: color => {
                if (!root.samplingScreen) return;
                root.chosen = color.toString() === "#e5484d" && Math.abs(picker.hue - color.hsvHue * 360) < 0.1 && Math.abs(picker.sat - color.hsvSaturation) < 0.01;
                resultDelay.start();
            }
        }
    }

    Timer {
        interval: 100
        running: true
        onTriggered: {
            const hex = root.findHex(picker);
            hex.text = "#0000ff";
            hex.editingFinished();
            if (Math.abs(picker.hue - 240) > 0.1) { console.error("COLOR_PICKER_TEST_FAIL hex HSV"); root.terminator.running = true; return; }
            input.mouseClick(root.findSwatch(picker));
            if (Math.abs(picker.hue - 120) > 0.1) { console.error("COLOR_PICKER_TEST_FAIL swatch HSV"); root.terminator.running = true; return; }
            root.samplingScreen = true;
            picker._pickFromScreen();
        }
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
