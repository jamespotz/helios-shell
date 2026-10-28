import QtQuick
import "../../services"
import "../../components"

// The recording Satellite's collapsed badge: the recording dot, plus the
// mic or camera while either is live.
Row {
    spacing: 6
    RecordingDot { anchors.verticalCenter: parent.verticalCenter }
    MaterialIcon {
        visible: MicActivity.isSystemMicActive || CameraActivity.isSystemCameraActive
        icon: CameraActivity.isSystemCameraActive ? "videocam" : "mic"
        font.pixelSize: 14
        color: Colors.danger
        anchors.verticalCenter: parent.verticalCenter
    }
}
