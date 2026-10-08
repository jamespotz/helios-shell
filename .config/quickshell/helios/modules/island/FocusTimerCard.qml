import QtQuick
import "../../services"
import "../../components"

Item {
    implicitWidth: Config.notifyWidth
    implicitHeight: content.implicitHeight
    Row {
        id: content
        width: parent.width
        spacing: 12
        MaterialIcon { icon: "timer"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
        Column {
            width: parent.width - 24 - 24 - closeButton.width
            spacing: 4
            StyledText { text: qsTr("Focus session complete"); width: parent.width; wrapMode: Text.Wrap; font.weight: Font.DemiBold }
            StyledText { text: qsTr("Take a moment to rest."); width: parent.width; wrapMode: Text.Wrap; color: Colors.subtext }
        }
        IconButton { id: closeButton; icon: "close"; label: qsTr("Dismiss timer alert"); onClicked: FocusTimer.dismissCompletion() }
    }
}
