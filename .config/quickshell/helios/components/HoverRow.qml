import QtQuick
import "../services"

// Apple-style list row — clean hover states with smooth transitions.
// Used in Wifi/Bluetooth/Volume device lists. Slightly taller (46px)
// for comfortable touch/click targets matching Apple HIG minimum 44pt.
Rectangle {
    id: root

    property bool highlighted: false
    readonly property bool hovering: hoverHandler.hovered

    signal clicked()

    height: 46
    radius: Colors.radiusSmall
    color: highlighted ? Colors.surfaceHigh : "transparent"
    opacity: root.enabled ? 1 : 0.4

    Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

    // Hover overlay — subtle, layered on top of highlight state
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colors.surfaceHigh
        opacity: root.hovering ? (root.highlighted ? 0.15 : 0.25) : 0

        Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
    }

    // Focus ring — keyboard-navigation feedback
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
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
        onClicked: root.clicked()
    }

    activeFocusOnTab: root.enabled
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
