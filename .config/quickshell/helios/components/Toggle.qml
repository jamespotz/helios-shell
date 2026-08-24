import QtQuick
import "../services"

// iOS-style toggle switch — matches Apple's dimensions (51x31 logical pt
// scaled down slightly for a desktop panel context). Uses accent green
// when on, neutral gray when off. The knob is pure white with a subtle
// shadow for depth.
Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 42
    implicitHeight: 24
    radius: height / 2
    color: checked ? Colors.success : Colors.surfaceHigh

    Behavior on color { ColorAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }

    // Knob with subtle shadow
    Rectangle {
        width: 18
        height: 18
        radius: 9
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3

        Behavior on x { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }

        // Knob shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.1)
            z: -1
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
