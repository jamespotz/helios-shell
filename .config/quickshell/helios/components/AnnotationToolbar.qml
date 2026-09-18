import QtQuick
import "../services"

// Pen toolbar — fixed color swatches, undo, close. Reused by the
// post-capture edit view and the live annotation overlay (the latter
// hosts this in the main island rather than floating over the canvas —
// see AnnotateToolbarIsland.qml).
Row {
    id: root

    required property AnnotationCanvas canvas
    signal closeRequested()

    readonly property var swatches: ["#e5484d", "#ffd60a", "#30d158", "#f5f5f7"]

    spacing: 10

    Repeater {
        model: root.swatches

        Rectangle {
            id: swatch
            required property string modelData
            width: 22
            height: 22
            radius: 11
            color: modelData
            border.width: root.canvas && root.canvas.currentColor.toString() === modelData ? 2 : 0
            border.color: Colors.text
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.canvas.currentColor = swatch.modelData
            }
        }
    }

    IconButton {
        icon: "undo"
        enabled: !!root.canvas && root.canvas.canUndo
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.canvas.undo()
    }

    IconButton {
        icon: "close"
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
            if (root.canvas) root.canvas.clear();
            root.closeRequested();
        }
    }
}
