import QtQuick
import "../services"

// Auto-hide overlay scroll thumb for a ListView/Flickable that truncates its
// content to a fixed height with no scrollbar of its own — without this, a
// longer list (more wifi networks, more bluetooth devices...) just looks cut
// off with no hint that scrolling reveals the rest. Floats over the target's
// own trailing edge rather than reserving a gutter, invisible until the list
// is hovered or actively scrolling — callers no longer need to shrink their
// Flickable/ListView width to make room for it.
Item {
    id: root

    required property Flickable target

    anchors.top: target.top
    anchors.bottom: target.bottom
    anchors.right: target.right
    anchors.rightMargin: 3
    width: 6
    visible: target.contentHeight > target.height + 1

    readonly property bool active: hoverHandler.hovered || target.moving
    opacity: active ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: root.active ? Config.animFast : Config.animSlow
            easing.type: Easing.OutCubic
        }
    }

    HoverHandler {
        id: hoverHandler
        target: root.target
    }

    Rectangle {
        width: parent.width
        radius: width / 2
        color: Colors.accent
        y: root.target.contentHeight > 0 ? (root.target.contentY / root.target.contentHeight) * root.height : 0
        height: root.target.contentHeight > 0 ? Math.max(24, (root.target.height / root.target.contentHeight) * root.height) : root.height
    }
}
