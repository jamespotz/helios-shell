import QtQuick
import Quickshell
import "../../services"
import "../../components"

Item {
    id: root
    readonly property var event: Calendar.upcomingAlert
    readonly property string joinUrl: root.event && root.event.links && root.event.links.length > 0 ? root.event.links[0].url : ""
    implicitWidth: 300
    implicitHeight: column.implicitHeight
    Column {
        id: column
        width: parent.width
        spacing: 12
        StyledText { text: qsTr("Upcoming meeting"); font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2 }
        StyledText {
            width: parent.width
            text: root.event ? root.event.summary : qsTr("No upcoming meeting")
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }
        StyledText {
            width: parent.width
            visible: !!root.event
            text: Calendar.upcomingMinutesUntil > 0 ? qsTr("Starts in %1 min").arg(Calendar.upcomingMinutesUntil) : qsTr("Starting now")
            color: Colors.subtext
        }
        StyledText { width: parent.width; visible: !!root.event && !!root.event.location; text: root.event ? root.event.location || "" : ""; color: Colors.subtext; wrapMode: Text.WordWrap }
        PrimaryButton {
            width: parent.width
            visible: root.joinUrl.length > 0
            text: qsTr("Join meeting")
            icon: "videocam"
            active: true
            onClicked: Quickshell.execDetached(["xdg-open", root.joinUrl])
        }
        PrimaryButton {
            width: parent.width
            text: qsTr("Dismiss reminder")
            icon: "close"
            enabled: !!root.event
            onClicked: Calendar.dismissAlert()
        }
    }
}
