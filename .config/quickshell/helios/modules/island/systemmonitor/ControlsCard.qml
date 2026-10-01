import QtQuick
import "../../../services"
import "../../../components"

MonitorCard {
    id: root

    title: "Controls"

    StatRow {
        width: parent.width
        icon: "videocam"
        label: "Camera"
        value: CameraActivity.isSystemCameraActive ? "In use" : "Not in use"
        valueColor: CameraActivity.isSystemCameraActive ? Colors.warning : Colors.text
        mono: false
    }
    StatRow {
        width: parent.width
        icon: "mic"
        label: "Microphone"
        value: MicActivity.isSystemMicActive ? "In use" : "Not in use"
        valueColor: MicActivity.isSystemMicActive ? Colors.warning : Colors.text
        mono: false
    }
    ToggleRow {
        width: parent.width
        icon: "coffee"
        title: "Keep Awake"
        subtitle: IdleInhibit.inhibited ? "Screen won't lock or sleep" : "Screen may sleep normally"
        checked: IdleInhibit.inhibited
        onToggled: IdleInhibit.toggleInhibit()
    }
}
