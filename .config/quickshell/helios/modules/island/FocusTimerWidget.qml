import QtQuick
import "../../services"
import "../../components"

HoverRow {
    required property var targetScreen
    readonly property bool hasContent: FocusTimer.active
    implicitWidth: countdownText.implicitWidth + 36
    height: Math.min(30, Config.idleBumpHeight)
    implicitHeight: height
    label: qsTr("Focus timer, %1 remaining").arg(FocusTimer.remainingText)
    StyledText { id: countdownText; anchors.centerIn: parent; text: FocusTimer.remainingText; font.pixelSize: Config.fontSize - 1 }
    onClicked: IslandNavigation.toggle(targetScreen.name, "focus")
}
