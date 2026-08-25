import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Apple menu bar clock — clean, medium weight text with subtle hover
// state. Shows abbreviated day, date, and time without seconds.
Item {
    id: root

    required property var targetScreen

    implicitWidth: text.implicitWidth
    implicitHeight: text.implicitHeight

    // Hover background — rounded pill, very subtle
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 8
        color: Colors.surfaceHigh
        opacity: clockHover.hovered ? 0.5 : 0

        Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
    }

    HoverHandler { id: clockHover }

    StyledText {
        id: text
        anchors.fill: parent
        font.weight: Font.Medium
        text: Qt.formatDateTime(clock.date, "ddd d MMM  " + Config.timeFormat)

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: Bridge.toggleIsland(root.targetScreen.name, "calendar")
    }
}
