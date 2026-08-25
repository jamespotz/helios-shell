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
    opacity: root.enabled ? 1 : 0.4
    color: checked ? Colors.success : Colors.surfaceHigh
    border.width: hoverHandler.hovered ? 2 : 0
    border.color: Colors.accent

    Behavior on color { ColorAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }

    // Knob — pure white regardless of theme, matching Apple's switch design
    Rectangle {
        width: 18
        height: 18
        radius: 9
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3

        Behavior on x { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
    }

    // Focus ring — keyboard-navigation feedback
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: parent.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Colors.accent
        visible: root.activeFocus
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }

    activeFocusOnTab: root.enabled
    Keys.onReturnPressed: root.toggled(!root.checked)
    Keys.onSpacePressed: root.toggled(!root.checked)
}
