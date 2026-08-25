import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../services"

Row {
    spacing: 4

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem
            required property var modelData

            width: 24
            height: 24

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Colors.surfaceHigh
                opacity: trayHover.hovered ? 0.6 : 0

                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }

            Image {
                anchors.fill: parent
                anchors.margins: 3
                source: trayItem.modelData.icon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            HoverHandler { id: trayHover }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        if (trayItem.modelData.hasMenu) {
                            // Map to screen-relative coordinates for the
                            // TrayMenu's positioning within its full-screen
                            // surface. mapToItem(null) gives coords in the
                            // Bar's surface space. The Bar is a top-anchored,
                            // horizontally-centered layer-shell surface.
                            const posInWindow = trayItem.mapToItem(null, mouse.x, mouse.y);
                            const screenW = QsWindow.window.screen.width;
                            const barSurfaceW = Config.islandMaxWidth;
                            const offsetX = (screenW - barSurfaceW) / 2;
                            const offsetY = Config.islandTopGap;
                            Bridge.openTrayMenu(
                                trayItem.modelData.menu,
                                QsWindow.window.screen.name,
                                offsetX + posInWindow.x,
                                offsetY + posInWindow.y
                            );
                        } else {
                            trayItem.modelData.secondaryActivate();
                        }
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayItem.modelData.secondaryActivate();
                    } else {
                        trayItem.modelData.activate();
                    }
                }
            }
        }
    }
}
