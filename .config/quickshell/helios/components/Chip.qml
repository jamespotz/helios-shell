import QtQuick
import "../services"

// Apple-style pill/chip selector — used for segmented options, filter
// tags, and small selectable values (theme schemes, EQ presets, scale
// options, security tags). Supports an optional leading item (icon, color
// swatch dots, etc.) via the default content property.
Rectangle {
    id: root

    property string text: ""
    property bool active: false
    // Most chips are accent-filled when active; a couple (e.g. Wi-Fi
    // security options) intentionally use a different semantic tint.
    property color tint: Colors.accent
    property color tintText: Colors.accentText
    default property alias leading: leadingRow.data

    signal clicked()

    implicitWidth: content.implicitWidth + 16
    implicitHeight: 28
    radius: height / 2
    opacity: root.enabled ? 1 : 0.4
    color: active ? root.tint : (hoverHandler.hovered ? Colors.surfaceHigh : Colors.surface)

    Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Row {
            id: leadingRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
        }

        StyledText {
            visible: root.text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: Config.fontSize - 2
            font.weight: Font.Medium
            color: root.active ? root.tintText : Colors.text
        }
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
        onClicked: root.clicked()
    }

    activeFocusOnTab: root.enabled
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
