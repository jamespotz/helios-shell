import QtQuick
import "../services"

// Apple-style icon button — clean circle with smooth state transitions.
// Active state uses accent fill; hover uses a subtle translucent overlay.
// Slightly larger hit target (30x30) for comfortable interaction.
Rectangle {
    id: root

    property string icon: ""
    property int iconSize: 16
    property bool active: false
    property color iconColor: Colors.text

    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    radius: height / 2
    opacity: root.enabled ? 1 : 0.4
    color: active ? Colors.accent
        : mouse.containsMouse ? Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.2)
        : "transparent"

    Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

    MaterialIcon {
        anchors.centerIn: parent
        icon: root.icon
        font.pixelSize: root.iconSize
        color: root.active ? Colors.accentText : root.iconColor
        opacity: root.active ? 1.0 : (mouse.containsMouse ? 1.0 : 0.85)

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

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    activeFocusOnTab: root.enabled
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
