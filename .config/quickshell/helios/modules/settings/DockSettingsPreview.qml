import QtQuick
import Quickshell
import "../../services"
import "../../components"
import "../dock"

// A small screen stage. Hover previews magnification; icons never launch apps.
Rectangle {
    id: root
    objectName: "dockSettingsPreview"
    implicitHeight: 160
    height: implicitHeight
    radius: Colors.radiusLarge
    color: Colors.surfaceHigh
    clip: true

    readonly property bool vertical: Dock.position !== "bottom"
    readonly property var apps: {
        const items = Dock.items.filter(item => !item.separator).slice(0, 3);
        return items.length ? items : [
            { key: "browser", icon: "web-browser", windows: [{}] },
            { key: "files", icon: "system-file-manager", windows: [{}, {}] },
            { key: "terminal", icon: "utilities-terminal", windows: [] }
        ];
    }
    readonly property var buttons: [
        { key: "apps", glyph: "apps", shown: Dock.showAppsButton, windows: [] },
        { key: "settings", glyph: "settings", shown: Dock.showSettingsButton, windows: [] },
        { key: "trash", glyph: "delete", shown: Dock.showTrash, windows: [] }
    ].filter(button => button.shown)
    readonly property var cells: root.apps.concat(root.buttons.length ? [{ separator: true }].concat(root.buttons) : [])

    Item {
        id: stage
        anchors.fill: parent
        anchors.margins: 18

        Item {
            id: body
            objectName: "dockPreviewBody"
            readonly property real naturalLength: root.cells.reduce((length, item) => length + (item.separator ? 9 : Dock.iconSize), 0)
                + Math.max(0, root.cells.length - 1) * Dock.iconSpacing + Dock.edgePadding * 2
            readonly property real naturalThickness: Dock.iconSize + Dock.edgePadding * 2
            readonly property real magnifyRoom: Dock.magnify && !Config.reducedMotion ? Dock.iconSize * (Dock.magnifyScale - 1) : 0
            readonly property real fit: Math.min(1,
                (stage.width - Dock.edgeGap) / (root.vertical ? naturalThickness + magnifyRoom : naturalLength),
                (stage.height - Dock.edgeGap) / (root.vertical ? naturalLength : naturalThickness + magnifyRoom))
            width: root.vertical ? naturalThickness : naturalLength
            height: root.vertical ? naturalLength : naturalThickness
            scale: fit
            transformOrigin: Item.TopLeft
            x: Dock.position === "left" ? Dock.edgeGap
                : Dock.position === "right" ? stage.width - width * fit - Dock.edgeGap
                : Dock.alignmentOffset(stage.width, width * fit)
            y: root.vertical ? Dock.alignmentOffset(stage.height, height * fit) : stage.height - height * fit - Dock.edgeGap
            opacity: Dock.enabled ? 1 : 0.4

            DockSurface { anchors.fill: parent }

            HoverHandler { id: bodyHover }

            Grid {
                id: icons
                anchors.centerIn: parent
                columns: root.vertical ? 1 : Math.max(1, root.cells.length)
                rowSpacing: Dock.iconSpacing
                columnSpacing: Dock.iconSpacing
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                Repeater {
                    model: root.cells
                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: root.vertical || !modelData.separator ? Dock.iconSize : 9
                        height: !root.vertical || !modelData.separator ? Dock.iconSize : 9

                        Rectangle {
                            visible: !!cell.modelData.separator
                            anchors.centerIn: parent
                            width: root.vertical ? Dock.iconSize - 12 : 1
                            height: root.vertical ? 1 : Dock.iconSize - 12
                            color: Colors.outline
                            opacity: 0.7
                        }

                        Item {
                            id: visual
                            objectName: "dockPreviewIcon_" + cell.index
                            visible: !cell.modelData.separator
                            anchors.fill: parent
                            transformOrigin: Dock.position === "left" ? Item.Left : Dock.position === "right" ? Item.Right : Item.Bottom
                            scale: {
                                if (!Dock.magnify || Config.reducedMotion || !bodyHover.hovered) return 1;
                                const along = root.vertical ? cell.y + cell.height / 2 : cell.x + cell.width / 2;
                                const pointer = (root.vertical ? bodyHover.point.position.y : bodyHover.point.position.x) - Dock.edgePadding;
                                const t = Math.min(1, Math.abs(along - pointer) / ((Dock.iconSize + Dock.iconSpacing) * 2.5));
                                return 1 + (Dock.magnifyScale - 1) * (Math.cos(Math.PI * t) + 1) / 2;
                            }
                            Behavior on scale { NumberAnimation { duration: Config.reducedMotion ? 0 : 90; easing.type: Easing.OutCubic } }

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: Dock.iconSize - 4
                                height: width
                                source: cell.modelData.icon ? Quickshell.iconPath(cell.modelData.icon, true) : ""
                                sourceSize: Qt.size(width * Dock.magnifyScale * 2, height * Dock.magnifyScale * 2)
                                mipmap: true
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                opacity: 0.92
                            }
                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: appIcon.status !== Image.Ready
                                icon: cell.modelData.glyph || "deployed_code"
                                font.pixelSize: Dock.iconSize - 12
                                renderType: Text.QtRendering
                                color: Colors.subtext
                            }
                        }

                        Grid {
                            readonly property int windowCount: (cell.modelData.windows || []).length
                            visible: windowCount > 0 && Dock.showIndicators
                            columns: root.vertical ? 1 : 3
                            spacing: 3
                            x: Dock.position === "left" ? -width - 1 : Dock.position === "right" ? parent.width + 1 : (parent.width - width) / 2
                            y: root.vertical ? (parent.height - height) / 2 : parent.height + 1
                            Repeater {
                                model: Dock.indicatorStyle === "windows" ? Math.min(3, parent.windowCount) : 1
                                Rectangle {
                                    readonly property real length: Dock.indicatorStyle === "line" ? Math.round(Dock.iconSize * 0.4)
                                        : Dock.indicatorStyle === "dot" && parent.windowCount > 1 ? 10 : 4
                                    width: root.vertical ? 4 : length
                                    height: root.vertical ? length : 4
                                    radius: 2
                                    color: Colors.subtext
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
