import QtQuick
import "../services"

// Row inside a SettingsCard: icon + label on the left, a control on the
// right, hairline below unless last.
Item {
    id: root
    default property alias control: controlSlot.children
    property string icon: ""
    property string label: ""
    property bool last: false

    width: parent ? parent.width : 0
    height: 44

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        MaterialIcon { icon: root.icon; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: root.label; anchors.verticalCenter: parent.verticalCenter }
    }

    Item {
        id: controlSlot
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    Rectangle {
        visible: !root.last
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.bottom: parent.bottom
        height: 1
        color: Colors.overlay
        opacity: 0.15
    }
}
