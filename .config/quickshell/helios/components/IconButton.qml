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

    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    radius: height / 2
    color: active ? Colors.accent
        : mouse.containsMouse ? Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.2)
        : "transparent"

    Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

    MaterialIcon {
        anchors.centerIn: parent
        icon: root.icon
        font.pixelSize: root.iconSize
        color: root.active ? Colors.accentText : Colors.text
        opacity: root.active ? 1.0 : (mouse.containsMouse ? 1.0 : 0.85)

        Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
