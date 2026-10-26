import QtQuick
import "../../services"
import "../../components"

// Standalone color picker, hosted in the main island (see IslandNavigation's
// "colorpicker" destination). Every chosen color is copied to the clipboard
// via Clipboard.copyText and
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
            Clipboard.copyText(color.toString());
        }
    }
}
