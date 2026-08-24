import QtQuick
import "../services"

Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 38
    implicitHeight: 22
    radius: height / 2
    color: checked ? Colors.accent : Colors.surfaceHigh
    Behavior on color { ColorAnimation { duration: Config.animFast } }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: root.checked ? Colors.accentText : Colors.text
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
