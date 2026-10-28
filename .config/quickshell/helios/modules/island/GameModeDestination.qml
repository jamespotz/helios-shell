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
        StyledText { text: qsTr("Game Mode"); font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2 }
        StyledText {
            width: parent.width
            text: qsTr("Blur and transparency are off, notifications are silenced, and the screen stays awake.")
            color: Colors.subtext
            wrapMode: Text.WordWrap
        }
        PrimaryButton {
            width: parent.width
            text: qsTr("Turn off Game Mode")
            icon: "sports_esports"
            enabled: GameMode.enabled
            onClicked: GameMode.setEnabled(false)
        }
    }
}
