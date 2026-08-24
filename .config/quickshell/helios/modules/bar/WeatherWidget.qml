import QtQuick
import "../../services"
import "../../components"

Item {
    id: root

    required property var targetScreen

    visible: Weather.available
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Colors.radiusSmall
        color: Colors.surfaceHigh
        opacity: weatherHover.hovered ? 1 : 0
    }

    HoverHandler { id: weatherHover }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        MaterialIcon {
            icon: Weather.icon
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(Weather.tempC) + "°C"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Bridge.toggleIsland(root.targetScreen.name, "weather")
    }
}
