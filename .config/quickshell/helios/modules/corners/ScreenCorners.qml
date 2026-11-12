import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../components"

// Rounds one screen's corners (Settings > Appearance > Screen corners):
// a small black fillet in each corner, so the panel reads as having
// rounded edges. One tiny surface per corner rather than a full-screen
// overlay, so the compositor only blends a few pixels. Never takes input.
// The border (Settings > Appearance > Screen edges) is one strip per edge
// that reserves its width, so windows, the Island and the Dock sit inside
// it; the corners then round its inner edge.
Scope {
    id: root
    required property var modelData

    Variants {
        model: Config.screenBorderWidth > 0 ? ["top", "bottom", "left", "right"] : []

        PanelWindow {
            required property string modelData
            screen: root.modelData

            // Bottom: above the wallpaper, below windows, and its zone is
            // reserved before the Island's (Top) and the Dock's.
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "helios:screen-border"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: modelData !== "bottom"
                bottom: modelData !== "top"
                left: modelData !== "right"
                right: modelData !== "left"
            }
            implicitWidth: Config.screenBorderWidth
            implicitHeight: Config.screenBorderWidth
            exclusiveZone: Config.screenBorderWidth
            color: "black"
            mask: Region {}
        }
    }

    Variants {
        model: Config.screenCornerRadius > 0 ? ["topLeft", "topRight", "bottomLeft", "bottomRight"] : []

        PanelWindow {
            required property string modelData
            screen: root.modelData

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "helios:screen-corner"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            margins {
                top: Config.screenBorderWidth
                bottom: Config.screenBorderWidth
                left: Config.screenBorderWidth
                right: Config.screenBorderWidth
            }
            anchors {
                top: modelData.startsWith("top")
                bottom: modelData.startsWith("bottom")
                left: modelData.endsWith("Left")
                right: modelData.endsWith("Right")
            }
            implicitWidth: Config.screenCornerRadius
            implicitHeight: Config.screenCornerRadius
            color: "transparent"
            mask: Region {}

            ConcaveCorner {
                size: Config.screenCornerRadius
                corner: modelData
            }
        }
    }
}
