import QtQuick
import "../../services"
import "../../components"

Item {
    implicitWidth: 280
    implicitHeight: column.implicitHeight
    Column {
        id: column
        width: parent.width
        spacing: 16
        StyledText { text: qsTr("Privacy"); font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2 }
        Repeater {
            model: [
                { label: qsTr("Microphone"), icon: "mic", active: MicActivity.isSystemMicActive, apps: MicActivity.activeApps },
                { label: qsTr("Camera"), icon: "videocam", active: CameraActivity.isSystemCameraActive, apps: CameraActivity.activeApps }
            ]
            Row {
                required property var modelData
                width: column.width
                spacing: 12
                MaterialIcon { icon: modelData.icon; color: modelData.active ? Colors.danger : Colors.subtext; font.pixelSize: 20 }
                Column {
                    width: parent.width - 32
                    spacing: 4
                    StyledText { text: modelData.label; font.weight: Font.Medium }
                    StyledText {
                        width: parent.width
                        text: modelData.active ? qsTr("In use by %1").arg([...new Set(modelData.apps)].join(", ") || qsTr("an application")) : qsTr("Not in use")
                        color: modelData.active ? Colors.danger : Colors.subtext
                        wrapMode: Text.WordWrap
                        font.pixelSize: Config.fontSize - 1
                    }
                }
            }
        }
    }
}
