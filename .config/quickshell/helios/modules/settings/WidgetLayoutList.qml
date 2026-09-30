import QtQuick
import "../../services"
import "../../components"

// Settings > Island — one surface's widgets ("idle" or "peek") as a
// reorderable card: drag a row or use the arrows to move it, the toggle to
// show it. The "|" marker reads as a "Right side" heading under a fixed
// "Left side" one; dragging it moves widgets between sides. Drag behaves
// like the Dock's pinned apps list (DockPinnedApps.qml).
Rectangle {
    id: root

    property string surface: "idle"
    // key → { icon, label }
    property var meta: ({})

    readonly property var layout: Config.layoutFor(root.surface)
    readonly property int rowHeight: 44
    property int dragIndex: -1
    property real dragDelta: 0
    readonly property int dropIndex: root.dragIndex < 0 ? -1
        : Math.max(0, Math.min(Math.round(root.dragIndex + root.dragDelta / root.rowHeight), root.layout.length - 1))

    width: parent ? parent.width : 0
    height: column.implicitHeight
    radius: Colors.radiusLarge
    color: Colors.surfaceHigh

    component SideHeading: StyledText {
        font.pixelSize: Config.fontSize - 1
        font.weight: Font.DemiBold
        color: Colors.subtext
    }

    Column {
        id: column
        width: parent.width

        Item {
            width: column.width
            height: 32

            SideHeading {
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: "Left side"
            }
        }

        Repeater {
            model: root.layout

            Item {
                id: widgetRow
                required property string modelData
                required property int index
                readonly property bool marker: widgetRow.modelData === "|"
                readonly property var info: root.meta[widgetRow.modelData] || ({ icon: "widgets", label: widgetRow.modelData })
                readonly property bool dragged: root.dragIndex === widgetRow.index
                property real pressY: 0

                width: column.width
                height: root.rowHeight
                z: widgetRow.dragged ? 1 : 0

                transform: Translate {
                    y: widgetRow.dragged ? root.dragDelta
                        : root.dragIndex < widgetRow.index && widgetRow.index <= root.dropIndex ? -root.rowHeight
                        : root.dropIndex <= widgetRow.index && widgetRow.index < root.dragIndex ? root.rowHeight : 0
                    Behavior on y {
                        enabled: !widgetRow.dragged && !Config.reducedMotion
                        NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: widgetRow.dragged
                    radius: Colors.radiusLarge
                    color: Colors.surfaceHigh
                    border.width: 1
                    border.color: Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.3)
                }

                // Below the buttons, so they keep their clicks.
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    // The Settings page scrolls; keep the drag.
                    preventStealing: true
                    cursorShape: widgetRow.dragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    // In column coordinates: the row itself moves while dragged.
                    function columnY(mouse) { return rowMouse.mapToItem(column, mouse.x, mouse.y).y; }
                    onPressed: mouse => { widgetRow.pressY = rowMouse.columnY(mouse); }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const delta = rowMouse.columnY(mouse) - widgetRow.pressY;
                        if (root.dragIndex < 0 && Math.abs(delta) > 4) root.dragIndex = widgetRow.index;
                        if (widgetRow.dragged) root.dragDelta = delta;
                    }
                    onReleased: {
                        if (!widgetRow.dragged) return;
                        const target = root.dropIndex;
                        root.dragIndex = -1;
                        root.dragDelta = 0;
                        if (target !== widgetRow.index) Config.moveWidget(root.surface, widgetRow.modelData, target);
                    }
                    onCanceled: if (widgetRow.dragged) { root.dragIndex = -1; root.dragDelta = 0; }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    MaterialIcon {
                        // Fixed width so "Left side" (leftMargin 34) lines up.
                        width: 16
                        icon: "drag_indicator"
                        font.pixelSize: 16
                        color: Colors.subtext
                        opacity: rowMouse.containsMouse || widgetRow.dragged ? 1 : 0.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MaterialIcon {
                        visible: !widgetRow.marker
                        icon: widgetRow.info.icon
                        font.pixelSize: 16
                        opacity: 0.8
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        visible: !widgetRow.marker
                        text: widgetRow.info.label
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    SideHeading {
                        visible: widgetRow.marker
                        text: "Right side"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconButton {
                        icon: "arrow_upward"
                        label: "Move up"
                        enabled: widgetRow.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Config.moveWidget(root.surface, widgetRow.modelData, widgetRow.index - 1)
                    }
                    IconButton {
                        icon: "arrow_downward"
                        label: "Move down"
                        enabled: widgetRow.index < root.layout.length - 1
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Config.moveWidget(root.surface, widgetRow.modelData, widgetRow.index + 1)
                    }
                    Item {
                        width: 52
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter

                        Toggle {
                            visible: !widgetRow.marker
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            label: widgetRow.info.label
                            checked: Config.widgetShown(root.surface, widgetRow.modelData)
                            onToggled: v => Config.setOption(Config.widgetOption(root.surface, widgetRow.modelData), v)
                        }
                    }
                }

                Rectangle {
                    visible: !widgetRow.dragged && widgetRow.index < root.layout.length - 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Colors.overlay
                    opacity: 0.15
                }
            }
        }
    }
}
