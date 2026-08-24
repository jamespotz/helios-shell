import QtQuick
import "../services"

Rectangle {
    id: root

    property string icon: ""
    property int iconSize: 18
    property bool active: false

    signal clicked()

    implicitWidth: 28
    implicitHeight: 28
    radius: height / 2
    color: active ? Colors.accent
        : mouse.containsMouse ? Colors.surfaceHigh : "transparent"

    Behavior on color { ColorAnimation { duration: Config.animFast } }

    MaterialIcon {
        anchors.centerIn: parent
        icon: root.icon
        font.pixelSize: root.iconSize
        color: root.active ? Colors.accentText : Colors.text
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
