import QtQuick
import Quickshell.Io
import "../../services"
import "../../components"

// Standalone color picker, hosted in the main island (see IslandNavigation's
// "colorpicker" destination). Every chosen color is copied to the clipboard
// via wl-copy — same one-shot Process pattern Screenshot.qml uses — and
// stays open until Escape (handled generically by the main island).
Item {
    id: root

    implicitWidth: picker.implicitWidth
    implicitHeight: picker.implicitHeight

    ColorPicker {
        id: picker
        recentColors: ColorPickerHistory.pickerRecents
        onColorChosen: color => {
            ColorPickerHistory.addPickerRecent(color);
            copyProc.command = ["sh", "-c", "printf '%s' \"$0\" | wl-copy", color.toString()];
            copyProc.running = false;
            copyProc.running = true;
        }
    }

    Process { id: copyProc }
}
