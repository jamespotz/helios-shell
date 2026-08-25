import QtQuick
import "../services"

// Pulsing red dot shown whenever screen recording is active — safety-
// critical status, kept identical wherever it appears (idle pill, hover
// peek). The pulse animation only runs while actually recording.
Rectangle {
    id: root

    visible: ScreenRecorder.recording
    width: 8
    height: 8
    radius: 4
    color: Colors.danger

    SequentialAnimation on opacity {
        running: ScreenRecorder.recording
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.3; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.3; to: 1; duration: 800; easing.type: Easing.InOutSine }
    }
}
