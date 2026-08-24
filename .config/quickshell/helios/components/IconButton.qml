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
    color: active ? Colors.accent : "transparent"

    Behavior on color { ColorAnimation { duration: Config.animFast } }

    // Hover feedback is intentionally not animated — with a Behavior here,
    // a quick mouse sweep across adjacent icons left the outgoing icon's
    // fade-out still visible while the next icon's fade-in started,
    // reading as two icons highlighted (or a smeared/misshapen highlight)
    // at once.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colors.surfaceHigh
        visible: !root.active && mouse.containsMouse
    }

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
