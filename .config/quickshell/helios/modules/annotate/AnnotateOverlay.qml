import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

Item {
    id: root

    Loader {
        active: AnnotateState.open

        sourceComponent: PanelWindow {
            id: overlay

            property alias canvasRef: canvas
            visible: AnnotateState.overlayVisible

            screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "helios:annotate"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusiveZone: -1

            // ---- ADD THE MASK HERE ----
            // This restricts input solely to the visual content bounds of `contentWrapper`.
            // Anything outside it (the top 40px margin area) will let clicks pass straight through!
            mask: Region {
                item: contentWrapper
            }

            Component.onCompleted: AnnotateState.canvas = canvas
            Component.onDestruction: AnnotateState.canvas = null

            // Give this wrapper an id so the mask property above can reference its geometry
            Item {
                id: contentWrapper
                anchors.fill: parent
                anchors.topMargin: Config.islandExclusiveZone + 40

                Image {
                    id: screenshotInfo
                    source: AnnotateState.editingScreenshot ? "file://" + AnnotateState.screenshotPath : ""
                    visible: false
                }

                AnnotationCanvas {
                    id: canvas
                    anchors.centerIn: parent
                    backgroundSource: AnnotateState.screenshotPath
                    width: AnnotateState.editingScreenshot && screenshotInfo.sourceSize.width > 0
                        ? screenshotInfo.sourceSize.width : parent.width
                    height: AnnotateState.editingScreenshot && screenshotInfo.sourceSize.height > 0
                        ? screenshotInfo.sourceSize.height : parent.height
                    scale: AnnotateState.editingScreenshot
                        ? Math.min(parent.width / width, parent.height / height) : 1
                    transformOrigin: Item.Center
                }
            }
        }
    }
}
