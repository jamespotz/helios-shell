import QtQuick
import "../../services"
import "../../components"

// Small clipboard-history indicator — click opens the island's clipboard
// tab. Usable both in the idle bump and the expanded island (PeekContent).
Item {
    id: root

    required property var targetScreen

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Colors.radiusSmall
        color: Colors.surfaceHigh
        opacity: clipboardHover.hovered ? 1 : 0
    }

    HoverHandler { id: clipboardHover }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        MaterialIcon { icon: "content_paste"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }

        StyledText {
            visible: Clipboard.items.length > 0
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Config.fontSize - 2
            text: Clipboard.items.length
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Bridge.toggleIsland(root.targetScreen.name, "clipboard")
    }
}
