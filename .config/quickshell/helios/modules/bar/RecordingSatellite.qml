import QtQuick
import "../../services"
import "../../components"

Item {
    id: root
    property string targetScreen: ""
    implicitWidth: 240
    implicitHeight: controls.implicitHeight

    Column {
        id: controls
        width: parent.width
        spacing: 12

        Row {
            spacing: 8
            RecordingDot { anchors.verticalCenter: parent.verticalCenter }
            StyledText {
                text: ScreenRecorder.recording ? qsTr("Recording %1").arg(ScreenRecorder.elapsedLabel) : qsTr("Recording finished")
                font.weight: Font.DemiBold
            }
        }
        PrimaryButton {
            width: parent.width
            text: qsTr("Stop recording")
            icon: "stop"
            enabled: ScreenRecorder.recording
            onClicked: ScreenRecorder.stop()
        }
        PrimaryButton {
            width: parent.width
            text: qsTr("Open Recorder")
            icon: "videocam"
            onClicked: {
                IslandNavigation.closeSatellite(root.targetScreen);
                IslandNavigation.show(root.targetScreen, "recorder");
            }
        }
    }
}
