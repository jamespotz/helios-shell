import QtQuick
import "../services"

// Pulsing red dot shown whenever screen recording is active. Safety-
// critical status, so it stays identical wherever it appears. The pulse
// animation only runs while actually recording.
//
// Sized and animated to stand out against its icon-sized neighbors in the
// row: a bigger base dot, plus a scale pulse in lockstep with the opacity
// pulse — scale is a paint-only transform, so it grows/shrinks in place
// without nudging sibling icons the way animating width/height would.
Rectangle {
    id: root

    visible: ScreenRecorder.recording
    width: 7
    height: 7
    radius: 3.5
    color: Colors.danger
    transformOrigin: Item.Center

    SequentialAnimation on opacity {
        running: ScreenRecorder.recording
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.3; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.3; to: 1; duration: 800; easing.type: Easing.InOutSine }
    }

    SequentialAnimation on scale {
        running: ScreenRecorder.recording
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 1.4; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.4; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
    }
}
