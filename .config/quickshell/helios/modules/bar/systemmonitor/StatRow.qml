import QtQuick
import "../../../services"
import "../../../components"

// "Label ........ value" row with an optional leading icon.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property color valueColor: Colors.text
    property bool mono: true

    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        MaterialIcon {
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            font.pixelSize: 14
            opacity: 0.6
        }
        StyledText {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            opacity: 0.7
            font.pixelSize: Config.fontSize - 2
        }
    }

    StyledText {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.valueColor
        font.pixelSize: Config.fontSize - 2
        font.family: root.mono ? Config.monoFontFamily : Config.fontFamily
    }
}
