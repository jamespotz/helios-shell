import QtQuick
import "../../services"
import "../../components"

// Main-island wrapper around AnnotationToolbar — see IslandNavigation's
// "annotate" destination. Guards on AnnotateState.canvas being set,
// covering the brief race between the drawing overlay's Loader and this
// panel's Loader both reacting to the same IPC toggle.
Item {
    id: root

    implicitWidth: controls.implicitWidth
    implicitHeight: controls.implicitHeight

    Row {
        id: controls
        visible: !!AnnotateState.canvas
        spacing: 10

        AnnotationToolbar {
            id: toolbar
            canvas: AnnotateState.canvas
            onCloseRequested: AnnotateState.editingScreenshot ? AnnotateState.cancelScreenshot() : AnnotateState.close()
        }

        PrimaryButton {
            id: saveButton
            visible: AnnotateState.editingScreenshot
            width: AnnotateState.editingScreenshot ? 64 : 0
            height: 32
            icon: AnnotateState.savingScreenshot ? "data_usage" : AnnotateState.screenshotSaveFailed ? "restart_alt" : "save"
            active: true
            enabled: !AnnotateState.savingScreenshot
            onClicked: AnnotateState.saveScreenshot()
        }
    }
}
