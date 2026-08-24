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
                            // Signal the bar to start its cooldown timer before
                            // the platform menu steals focus.
                            Bridge.trayMenuOpen = !Bridge.trayMenuOpen;
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
