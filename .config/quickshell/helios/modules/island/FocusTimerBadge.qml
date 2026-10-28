import QtQuick
import "../../services"
import "../../components"

// The focus timer Satellite's collapsed badge: kind icon and time left.
Row {
    id: root
    // Wide enough for the time, which changes width as it counts down.
    readonly property real badgeWidth: remaining.implicitWidth + Config.fontSize + 6 + 20
    readonly property color timerColor: FocusTimer.state.status === "paused" ? Colors.subtext : Colors.accent
    spacing: 6
    MaterialIcon {
        icon: FocusTimer.state.kind === "focus" ? "timer" : "coffee"
        font.pixelSize: Config.fontSize
        color: root.timerColor
        anchors.verticalCenter: parent.verticalCenter
    }
    StyledText {
        id: remaining
        text: FocusTimer.remainingText
        font.pixelSize: Config.fontSize - 1
        font.weight: Font.DemiBold
        color: root.timerColor
        anchors.verticalCenter: parent.verticalCenter
    }
}
