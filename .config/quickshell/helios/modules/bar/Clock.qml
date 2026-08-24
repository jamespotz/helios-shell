import QtQuick
import Quickshell
import "../../services"
import "../../components"

Item {
    id: root

    required property var targetScreen

    implicitWidth: text.implicitWidth
    implicitHeight: text.implicitHeight

    StyledText {
        id: text
        anchors.fill: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM  h:mm AP")
        font.bold: true

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Bridge.toggleIsland(root.targetScreen.name, "calendar")
    }
}
