import QtQuick
import "../services"

// Full-screen dim backdrop with click-to-dismiss, used behind modal
// surfaces (the polkit auth prompt; the launcher's own right-click context
// menu, at dimOpacity 0 purely for its click-outside-to-dismiss behavior)
// to focus attention on the panel above it.
Rectangle {
    id: root

    property bool active: false
    property real dimOpacity: 0.45

    signal dismissed()

    anchors.fill: parent
    color: Colors.shadow
    opacity: root.active ? root.dimOpacity : 0
    Behavior on opacity { NumberAnimation { duration: Config.animMedium } }

    MouseArea {
        anchors.fill: parent
        enabled: root.active
        onClicked: root.dismissed()
    }
}
