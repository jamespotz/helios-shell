import QtQuick
import "../../services"
import "../../components"

PanelBackground {
    id: root

    property string icon: ""
    property string label: ""
    property bool destructive: false
    property bool armed: false

    signal activated()
    signal armRequested()

    function activate() {
        if (!root.destructive || root.armed)
            root.activated();
        else
            root.armRequested();
    }

    width: 110
    height: 110
    color: armed ? Colors.danger : Colors.surface
    Behavior on color { ColorAnimation { duration: Config.animFast } }

    Column {
        anchors.centerIn: parent
        spacing: 8

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.icon
            font.pixelSize: 30
            color: root.armed ? Colors.accentText : Colors.text
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.armed ? "Confirm?" : root.label
            color: root.armed ? Colors.accentText : Colors.text
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Colors.surfaceHigh
        opacity: actionHover.hovered ? 0.15 : 0
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

    HoverHandler { id: actionHover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: root.activate()
    Keys.onSpacePressed: root.activate()
}
