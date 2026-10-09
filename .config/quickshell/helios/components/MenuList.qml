import QtQuick
import "../services"

// Compact context menu — a panel with one row per entry. Each entry is
// { label, run, danger? }; run() is called on click or Enter, then
// triggered(). Up/Down move the highlight, Esc emits dismissed(). Scrolls
// when taller than maxHeight. Used by the Launcher and the Dock right-click
// menus; call forceActiveFocus() after opening for keyboard use.
Item {
    id: root

    property var entries: []
    property real maxHeight: Infinity
    property int currentIndex: -1

    signal triggered()
    onTriggered: AlertSounds.play("tap")
    signal dismissed()

    function _run(index) {
        const entry = root.entries[index];
        if (!entry) return;
        entry.run();
        root.triggered();
    }

    implicitWidth: 200
    implicitHeight: Math.min(menuColumn.implicitHeight + 8, root.maxHeight)
    onEntriesChanged: root.currentIndex = -1
    onVisibleChanged: root.currentIndex = -1

    Keys.onEscapePressed: root.dismissed()
    Keys.onUpPressed: root.currentIndex = root.currentIndex <= 0 ? root.entries.length - 1 : root.currentIndex - 1
    Keys.onDownPressed: root.currentIndex = (root.currentIndex + 1) % Math.max(1, root.entries.length)
    Keys.onReturnPressed: root._run(root.currentIndex)
    Keys.onEnterPressed: root._run(root.currentIndex)

    SurfaceBackground {
        anchors.fill: parent
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 4
        contentHeight: menuColumn.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: menuColumn
            width: flick.width
            spacing: 2

            Repeater {
                model: root.entries

                delegate: Rectangle {
                    id: entryRow
                    required property var modelData
                    required property int index
                    readonly property bool highlighted: entryRow.index === root.currentIndex

                    width: menuColumn.width
                    height: 32
                    radius: 8
                    color: entryMouse.pressed ? Colors.overlay
                        : entryMouse.containsMouse || entryRow.highlighted ? Colors.surfaceHigh : "transparent"

                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    // Keep the keyboard highlight in view when scrolling.
                    onHighlightedChanged: {
                        if (!entryRow.highlighted) return;
                        if (entryRow.y < flick.contentY) flick.contentY = entryRow.y;
                        else if (entryRow.y + height > flick.contentY + flick.height) flick.contentY = entryRow.y + height - flick.height;
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: entryRow.modelData.label
                        color: entryRow.modelData.danger ? Colors.danger : Colors.text
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._run(entryRow.index)
                    }
                }
            }
        }
    }
}
