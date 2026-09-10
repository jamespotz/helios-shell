import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool destructive: false
    property bool armed: false

    signal activated()
    signal armRequested()

    readonly property bool dangerActive: destructive && (armed || actionHover.hovered)

    function activate() {
        if (!root.destructive || root.armed)
            root.activated();
        else
            root.armRequested();
    }

    implicitWidth: 84
    implicitHeight: 84
    scale: Config.reducedMotion ? 1 : actionMouse.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: Config.reducedMotion ? 0 : Config.animFast; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: Colors.radiusSmall
        color: root.dangerActive ? Colors.danger : Colors.surfaceHigh
        opacity: root.armed ? 1 : (actionHover.hovered ? (root.destructive ? 0.9 : 0.6) : 0)
        Behavior on color { ColorAnimation { duration: Config.animFast } }
        Behavior on opacity { NumberAnimation { duration: Config.animFast } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.icon
            font.pixelSize: 30
            color: root.dangerActive ? Qt.lighter(Colors.danger, 1.4) : Colors.text
            Behavior on color { ColorAnimation { duration: Config.animFast } }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.armed ? "Confirm?" : root.label
            color: root.dangerActive ? Colors.accentText : root.armed ? Colors.accentText : Colors.subtext
        }
    }

    // Focus ring — keyboard-navigation feedback
    Rectangle {
        anchors.fill: parent
        radius: Colors.radiusSmall
        color: "transparent"
        border.width: 2
        border.color: Colors.accent
        visible: root.activeFocus
    }

    HoverHandler { id: actionHover }

    MouseArea {
        id: actionMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: root.activate()
    Keys.onSpacePressed: root.activate()
}
