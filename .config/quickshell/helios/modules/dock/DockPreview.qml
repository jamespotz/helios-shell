import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../components"

// Window previews for one Dock item — a live thumbnail and title per
// window. Clicking a card focuses that window.
Item {
    id: root

    property var item: null
    property real maxWidth: 800
    readonly property bool hovered: previewHover.hovered

    readonly property var windows: root.item ? root.item.windows : []
    readonly property int pad: 8
    readonly property int cardSpacing: 6
    readonly property real cardWidth: Math.min(220, (root.maxWidth - root.pad * 2 - root.cardSpacing * (root.windows.length - 1)) / Math.max(1, root.windows.length))
    readonly property real thumbHeight: root.cardWidth * 9 / 16

    implicitWidth: cards.implicitWidth + root.pad * 2
    implicitHeight: cards.implicitHeight + root.pad * 2

    HoverHandler { id: previewHover }

    PanelBackground {
        anchors.fill: parent
    }

    Row {
        id: cards
        anchors.centerIn: parent
        spacing: root.cardSpacing

        Repeater {
            model: root.windows

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var toplevel: card.modelData.toplevel

                width: root.cardWidth
                height: cardColumn.implicitHeight + 12
                radius: Colors.radiusSmall
                color: cardMouse.pressed ? Colors.overlay
                    : cardMouse.containsMouse ? Colors.surfaceHigh : "transparent"
                Behavior on color { ColorAnimation { duration: Config.animFast } }

                // Below the content so the close button gets its own clicks.
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Dock.markSeen(root.item.key);
                        AppLaunch.focusAddress(card.modelData.address);
                    }
                }

                Column {
                    id: cardColumn
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 12
                    spacing: 6

                    Rectangle {
                        width: parent.width
                        height: root.thumbHeight
                        radius: 6
                        color: Colors.surface
                        clip: true

                        ScreencopyView {
                            id: thumb
                            anchors.fill: parent
                            captureSource: root.visible && card.toplevel ? card.toplevel.wayland : null
                            live: root.visible
                            constraintSize: Qt.size(width, height)
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !thumb.hasContent
                            icon: "web_asset"
                            font.pixelSize: 28
                            color: Colors.subtext
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            width: parent.width - closeButton.width - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.toplevel ? card.toplevel.title : ""
                            font.pixelSize: Config.fontSize - 1
                            elide: Text.ElideRight
                        }

                        IconButton {
                            id: closeButton
                            icon: "close"
                            iconSize: 14
                            implicitWidth: 22
                            implicitHeight: 22
                            label: "Close window"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: Dock.closeWindow(card.modelData.address)
                        }
                    }
                }

            }
        }
    }
}
