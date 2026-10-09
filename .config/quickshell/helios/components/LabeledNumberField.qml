import QtQuick
import "../services"

Row {
    id: root

    property string label: ""
    property bool showLabel: true
    property real inputWidth: 70
    property int value: 0
    property int minValue: 0
    property int maxValue: 999
    readonly property bool acceptableInput: input.acceptableInput

    signal valueEdited(int value)

    spacing: root.showLabel ? 8 : 0

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showLabel
        width: root.showLabel ? 90 : 0
        text: root.label
        opacity: 0.7
        font.pixelSize: Config.fontSize - 2
    }

    Rectangle {
        width: root.inputWidth
        height: 32
        radius: height / 2
        color: Colors.surfaceHigh
        border.width: input.activeFocus ? 1 : 0
        border.color: Colors.accent
        anchors.verticalCenter: parent.verticalCenter

        TextInput {
            id: input
            Accessible.role: Accessible.EditableText
            Accessible.name: root.label
            activeFocusOnTab: true
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
                if (isNaN(v)) return;
                const clamped = Math.max(root.minValue, Math.min(root.maxValue, v));
                // Leaving the field unchanged isn't an edit, so it stays quiet.
                if (clamped !== root.value) AlertSounds.play("tick");
                root.valueEdited(clamped);
            }
        }
    }
}
