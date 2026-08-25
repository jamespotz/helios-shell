import QtQuick
import "../services"

// Full-width prominent action button — accent-filled when active/primary,
// neutral surface otherwise. Used for standalone CTAs like "Scan", "Join",
// or "Dynamic (from wallpaper)" that previously each hand-rolled their own
// hover/active Rectangle.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool active: false
    // Most CTAs are accent-filled when active; a couple (e.g. Wi-Fi "Join")
    // intentionally use a different semantic tint to stand apart from it.
    property color tint: Colors.accent
    property color tintText: Colors.accentText
    default property alias trailing: trailingRow.data

    signal clicked()

    implicitHeight: 44
    radius: Colors.radiusSmall
    opacity: root.enabled ? 1 : 0.4
    color: active ? root.tint : (hoverHandler.hovered ? Colors.surfaceHigh : Colors.surface)

    Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

    Row {
        anchors.centerIn: parent
        spacing: 8

        MaterialIcon {
            visible: root.icon.length > 0
            icon: root.icon
            font.pixelSize: 18
            color: root.active ? root.tintText : Colors.text
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.text
            color: root.active ? root.tintText : Colors.text
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            id: trailingRow
            anchors.verticalCenter: parent.verticalCenter
        }
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
