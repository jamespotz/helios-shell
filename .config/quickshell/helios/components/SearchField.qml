import QtQuick
import "../services"

// Prominent Apple-style search/filter bar — icon + text input with a
// placeholder that fades out on entry. Used by the launcher and the
// keybinds cheat sheet.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Search…"
    property int inputPixelSize: Config.fontSize

    signal accepted()
    signal escapePressed()
    signal upPressed()
    signal downPressed()

    function focusInput() { input.forceActiveFocus(); }

    height: 46
    radius: Colors.radiusSmall
    color: Colors.surfaceHigh

    Row {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        MaterialIcon {
            icon: "search"
            font.pixelSize: 18
            color: Colors.subtext
            anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
            id: input
            width: parent.width - 28 - 10
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.text
            font.family: Config.fontFamily
            font.pixelSize: root.inputPixelSize
            clip: true

            Keys.onEscapePressed: root.escapePressed()
            Keys.onReturnPressed: root.accepted()
            Keys.onUpPressed: root.upPressed()
            Keys.onDownPressed: root.downPressed()

            StyledText {
                visible: input.text.length === 0
                text: root.placeholder
                color: Colors.subtext
                font.pixelSize: input.font.pixelSize
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
