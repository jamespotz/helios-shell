import QtQuick
import "../services"

// Prominent Apple-style search/filter bar — icon + text input with a
// placeholder that fades out on entry. Used by the launcher and the
// keybinds cheat sheet.
Rectangle {
    id: root

    property alias text: input.text
    property alias cursorPosition: input.cursorPosition
    property string placeholder: "Search…"
    property string icon: "search"
    property int inputPixelSize: Config.fontSize
    readonly property bool inputActiveFocus: input.activeFocus
    // Routes Left/Right to leftPressed/rightPressed instead of the text
    // cursor, for fields driving a grid.
    property bool captureHorizontal: false

    signal accepted()
    signal escapePressed()
    signal upPressed()
    signal downPressed()
    signal leftPressed()
    signal rightPressed()

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
            icon: root.icon
            font.pixelSize: 18
            color: Colors.subtext
            anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
            id: input
            Accessible.role: Accessible.EditableText
            Accessible.name: root.placeholder
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
            Keys.onLeftPressed: event => { if (root.captureHorizontal) root.leftPressed(); else event.accepted = false; }
            Keys.onRightPressed: event => { if (root.captureHorizontal) root.rightPressed(); else event.accepted = false; }

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
