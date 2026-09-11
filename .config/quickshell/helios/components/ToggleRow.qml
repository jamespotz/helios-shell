import QtQuick
import "../services"

// Labeled toggle row — leading icon, title + subtitle, switch on the right.
// Used for settings-style options inside island panels (e.g. Screenshot's
// "Extract text (OCR)", ScreenRecorder's "Desktop audio").
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool enabled: true

    signal toggled(bool checked)

    implicitHeight: rowLayout.height

    Item {
        id: rowLayout
        width: parent.width
        height: Math.max(labelCol.implicitHeight, toggle.height)
        opacity: root.enabled ? 1 : 0.4

        readonly property int leadWidth: root.icon.length > 0 ? 28 : 0

        MaterialIcon {
            visible: root.icon.length > 0
            icon: root.icon
            font.pixelSize: 18
            color: Colors.accent
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            id: labelCol
            x: rowLayout.leadWidth
            width: rowLayout.width - rowLayout.leadWidth - toggle.width - 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: root.title
                font.pixelSize: Config.fontSize - 1
                font.weight: Font.Medium
            }

            StyledText {
                width: parent.width
                text: root.subtitle
                font.pixelSize: Config.fontSize - 3
                opacity: 0.6
                wrapMode: Text.WordWrap
            }
        }

        Toggle {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            enabled: root.enabled
            onToggled: v => root.toggled(v)
        }
    }
}
