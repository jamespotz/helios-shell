pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Recent-color list for the standalone color picker (ColorPickerIsland).
// The annotation toolbar went back to fixed swatches, so this no longer
// needs to track a second, independent list.
QtObject {
    id: root

    readonly property int _maxEntries: 5

    property alias pickerRecents: adapter.pickerRecents

    function addPickerRecent(color) {
        const hex = color.toString();
        const filtered = adapter.pickerRecents.filter(c => c !== hex);
        filtered.unshift(hex);
        adapter.pickerRecents = filtered.slice(0, root._maxEntries);
    }

    property FileView historyFile: FileView {
        path: Quickshell.statePath("colorpicker-history.json")
        watchChanges: false

        JsonAdapter {
            id: adapter
            property var pickerRecents: []
        }
    }
}
