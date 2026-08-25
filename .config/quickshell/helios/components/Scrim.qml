import QtQuick
import "../services"

// Full-screen dim backdrop with click-to-dismiss, used behind modal
// surfaces (launcher, keybinds cheat sheet, power menu) to focus attention
// on the panel above it.
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
        onClicked: root.dismissed()
    }
}
