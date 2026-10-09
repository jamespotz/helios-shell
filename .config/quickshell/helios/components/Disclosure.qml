import QtQuick
import "../services"

// Collapsible "Options" section — chevron + title, collapsed-state summary
// on the right, expands to reveal `contentChildren`. Same disclosure
// interaction as ThemeDestination's theme grid, generalized for reuse across
// island panels.
Column {
    id: root

    property bool open: false
    property string title: "Options"
    property string summary: ""
    default property alias contentChildren: contentCol.children

    width: parent.width
    spacing: 10

    Item {
        id: header
        objectName: "disclosureHeader"
        signal clicked()
        onClicked: { AlertSounds.play("tap"); root.open = !root.open; }
        activeFocusOnTab: enabled
        Keys.onReturnPressed: if (enabled) clicked()
        Keys.onSpacePressed: if (enabled) clicked()
        Accessible.role: Accessible.Button
        Accessible.name: root.title
        Accessible.description: root.open ? qsTr("Expanded") : qsTr("Collapsed")
        Accessible.onPressAction: if (enabled) clicked()
        width: parent.width
        height: 22

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            MaterialIcon {
                icon: root.open ? "expand_less" : "chevron_right"
                font.pixelSize: 16
                opacity: 0.7
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.title
                font.underline: header.activeFocus
                font.pixelSize: Config.fontSize - 1
                opacity: 0.8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StyledText {
            visible: !root.open && root.summary.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.summary
            font.pixelSize: Config.fontSize - 2
            opacity: 0.5
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: header.clicked()
        }
    }

    Column {
        id: contentCol
        visible: root.open
        width: parent.width
        spacing: 14
    }
}
