import QtQuick
import "../../services"
import "../../components"

Item {
    implicitWidth: Config.notifyWidth
    implicitHeight: content.implicitHeight
    Column {
        id: content
        width: parent.width
        spacing: 12
        Row {
            width: parent.width
            spacing: 12
            MaterialIcon { icon: FocusTimer.state.kind === "focus" ? "timer" : "coffee"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            Column {
                width: parent.width - 24 - 24 - closeButton.width
                spacing: 4
                StyledText { text: FocusTimer.state.kind === "focus" ? qsTr("Focus session complete") : qsTr("Break complete"); width: parent.width; wrapMode: Text.Wrap; font.weight: Font.DemiBold }
                StyledText { text: FocusTimer.state.kind === "focus" ? qsTr("Take a moment to rest.") : qsTr("Ready for another focus session?"); width: parent.width; wrapMode: Text.Wrap; color: Colors.subtext }
            }
            IconButton { id: closeButton; icon: "close"; label: qsTr("Dismiss timer alert"); onClicked: FocusTimer.dismissCompletion() }
        }
    }
}
