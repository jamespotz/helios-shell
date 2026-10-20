import QtQuick
import "../../services"
import "../../components"

// GitHub unread indicator — click opens the GitHub destination. Usable both
// in the idle bump and the expanded island (IslandPeek).
Item {
    id: root

    required property var targetScreen
    readonly property int unread: GitHub.items.length

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Colors.radiusSmall
        color: Colors.surfaceHigh
        opacity: githubHover.hovered ? 1 : 0
    }

    HoverHandler { id: githubHover }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        GitHubMark {
            size: 14
            color: root.unread > 0 ? Colors.accent : Colors.text
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: root.unread > 0
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Config.fontSize - 2
            text: root.unread
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            AlertSounds.play("tap");
            IslandNavigation.toggle(root.targetScreen.name, "github");
        }
    }
}
