import QtQuick
import "../services"

// Thin track+thumb for a ListView/Flickable that truncates its content to a
// fixed height with no scrollbar of its own — without this, a longer list
// (more wifi networks, more bluetooth devices...) just looks cut off with no
// hint that scrolling reveals the rest. Sits in a small gutter reserved to
// its left by the caller (target.width should leave room for it).
Item {
    id: root

    required property Flickable target

    anchors.top: target.top
    anchors.bottom: target.bottom
    anchors.left: target.right
    anchors.leftMargin: 4
    width: 4
    visible: target.contentHeight > target.height + 1

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: Colors.overlay
        opacity: 0.3
    }

    Rectangle {
        width: parent.width
        radius: 2
        color: Colors.accent
        y: root.target.contentHeight > 0 ? (root.target.contentY / root.target.contentHeight) * root.height : 0
        height: root.target.contentHeight > 0 ? Math.max(20, (root.target.height / root.target.contentHeight) * root.height) : root.height
    }
}
