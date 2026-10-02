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
        StyledText { text: qsTr("Caffeine"); font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2 }
        StyledText {
            width: parent.width
            text: IdleInhibit.inhibited ? qsTr("Screen dimming, sleep, and auto-lock are paused.")
                : IdleInhibit.enabled ? qsTr("Your normal idle settings are active.") : qsTr("Automatic idle handling is disabled.")
            color: Colors.subtext
            wrapMode: Text.WordWrap
        }
        PrimaryButton {
            width: parent.width
            text: qsTr("Turn off caffeine")
            icon: "coffee"
            enabled: IdleInhibit.inhibited
            onClicked: IdleInhibit.toggleInhibit()
        }
    }
}
