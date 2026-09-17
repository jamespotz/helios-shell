import QtQuick
import "../services"

Row {
    id: root

    property string label: ""
    property real value: 0
    property real minValue: 0
    property real maxValue: 1
    property int decimals: 2

    signal valueEdited(real value)

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
            text: root.value.toFixed(root.decimals)
            validator: DoubleValidator { bottom: root.minValue; top: root.maxValue; decimals: root.decimals }

            onEditingFinished: {
                const v = parseFloat(text);
                if (!isNaN(v)) root.valueEdited(Math.max(root.minValue, Math.min(root.maxValue, v)));
            }
        }
    }
}
