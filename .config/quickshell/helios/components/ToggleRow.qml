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

    implicitHeight: rowLayout.implicitHeight

    Row {
        id: rowLayout
        width: parent.width
        spacing: 10
        opacity: root.enabled ? 1 : 0.4

        MaterialIcon {
            icon: root.icon
            font.pixelSize: 18
            color: Colors.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: rowLayout.width - 18 - toggle.width - rowLayout.spacing * 2
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
            anchors.verticalCenter: parent.verticalCenter
            checked: root.checked
            enabled: root.enabled
            onToggled: v => root.toggled(v)
        }
    }
}
