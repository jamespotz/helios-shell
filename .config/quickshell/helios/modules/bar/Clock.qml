import QtQuick
import Quickshell
import "../../services"
import "../../components"

Item {
    id: root

    required property var targetScreen

    implicitWidth: text.implicitWidth
    implicitHeight: text.implicitHeight

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Colors.radiusSmall
        color: Colors.surfaceHigh
        opacity: clockHover.hovered ? 1 : 0
    }

    HoverHandler { id: clockHover }

    StyledText {
        id: text
        anchors.fill: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM  h:mm AP")

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
