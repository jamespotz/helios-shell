import QtQuick
import "../../services"
import "../../components"

// Compact weather indicator for the peek bar — icon + temperature with
// a subtle hover pill. Apple-style: clean, no borders, just a soft
// background on interaction.
Item {
    id: root

    required property var targetScreen

    visible: Weather.available
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Hover pill background
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 8
        color: Colors.surfaceHigh
        opacity: weatherHover.hovered ? 0.5 : 0

        Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
    }

    HoverHandler { id: weatherHover }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        MaterialIcon {
            icon: Weather.icon
            font.pixelSize: 16
            color: Colors.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            font.weight: Font.Medium
            text: Math.round(Weather.tempC) + "°"
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: Bridge.toggleIsland(root.targetScreen.name, "weather")
    }
}
