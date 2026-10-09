import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"

// Brief flash over the area a screenshot just captured, fired with the
// shutter sound so the two land together. It flashes the captured region
// itself, not the whole screen, so it's clear what was taken. One per
// screen; the surface exists only while flashing and never takes input.
// Reduce motion skips it: a sudden brightness change is what that setting
// avoids, and the shutter sound and notification still confirm the capture.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:capture-flash"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    mask: Region {}
    visible: flash.running

    Connections {
        target: Screenshot
        function onCaptured(geometry) {
            if (Config.reducedMotion) return;
            // Empty geometry is a capture of every output.
            const match = /^(-?\d+),(-?\d+) (\d+)x(\d+)$/.exec(geometry);
            const x = match ? Number(match[1]) - root.modelData.x : 0;
            const y = match ? Number(match[2]) - root.modelData.y : 0;
            const w = match ? Number(match[3]) : root.modelData.width;
            const h = match ? Number(match[4]) : root.modelData.height;
            if (x >= root.modelData.width || y >= root.modelData.height || x + w <= 0 || y + h <= 0) return;
            area.x = x;
            area.y = y;
            area.width = w;
            area.height = h;
            flash.restart();
        }
    }

    // A camera flash is white whatever the theme.
    Rectangle {
        id: area
        color: "white"
        opacity: 0
    }

    // Fast in, slower out: the light arrives with the shutter and fades.
    SequentialAnimation {
        id: flash
        NumberAnimation { target: area; property: "opacity"; to: 0.3; duration: 40; easing.type: Easing.OutCubic }
        NumberAnimation { target: area; property: "opacity"; to: 0; duration: Config.animMedium; easing.type: Easing.OutCubic }
    }
}
