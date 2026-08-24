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

            width: 22
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Colors.surfaceHigh
                opacity: trayHover.hovered ? 1 : 0
            }

            Image {
                anchors.fill: parent
                anchors.margins: 2
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
                        // Full app-provided context menu (all entries the app
                        // registered via its StatusNotifierItem/DBusMenu),
                        // not just the single secondaryActivate() shortcut.
                        if (trayItem.modelData.hasMenu) {
                            const pos = trayItem.mapToItem(QsWindow.contentItem, mouse.x, mouse.y);
                            trayItem.modelData.display(QsWindow.window, pos.x, pos.y);
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
