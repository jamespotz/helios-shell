import QtQuick
import "../services"

Row {
    id: root

    property string label: ""
    property int value: 0
    property int minValue: 0
    property int maxValue: 999

    signal valueEdited(int value)

    spacing: 8

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: 90
        text: root.label
        opacity: 0.7
        font.pixelSize: Config.fontSize - 2
    }

    Rectangle {
        width: 70
        height: 32
        radius: height / 2
        color: Colors.surface
        anchors.verticalCenter: parent.verticalCenter

        TextInput {
            anchors.fill: parent
            anchors.margins: 8
            color: Colors.text
            font.family: Config.fontFamily
            font.pixelSize: Config.fontSize
            clip: true
            text: root.value.toString()
            validator: IntValidator { bottom: root.minValue; top: root.maxValue }

            onEditingFinished: {
                const v = parseInt(text);
                if (!isNaN(v)) root.valueEdited(Math.max(root.minValue, Math.min(root.maxValue, v)));
            }
        }
    }
}
