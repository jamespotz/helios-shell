import QtQuick
import "../services"

// Bold section title with an optional dimmed subtitle, above a SettingsCard.
Column {
    id: root
    property string title: ""
    property string subtitle: ""

    width: parent ? parent.width : 0
    spacing: 2

    StyledText { font.bold: true; text: root.title }
    StyledText {
        visible: text !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        opacity: 0.6
        font.pixelSize: Config.fontSize - 2
        text: root.subtitle
    }
}
