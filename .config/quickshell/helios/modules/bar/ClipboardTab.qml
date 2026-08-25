import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"
import "../../components"

Item {
    id: root

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 28

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                MaterialIcon { anchors.verticalCenter: parent.verticalCenter; icon: "content_paste" }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clipboard.items.length + " items"
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IconButton {
                    icon: "delete_sweep"
                    iconSize: 16
                    onClicked: Clipboard.clearAll()
                }

                IconButton {
                    icon: "refresh"
                    iconSize: 16
                    onClicked: Clipboard.refresh()
                }
            }
        }

        StyledText {
            visible: Clipboard.items.length === 0
            text: "No clipboard history"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        ListView {
            id: clipList
            width: parent.width - 8
            visible: Clipboard.items.length > 0
            height: Math.min(280, Math.max(0, Clipboard.items.length * 46))
            clip: true
            spacing: 2
            model: Clipboard.items
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: clipList }

            delegate: HoverRow {
                id: row
                required property var modelData
                required property int index

                readonly property string thumbPath: Quickshell.env("HOME") + "/.cache/helios/clip-thumbs/" + modelData.id + ".img"
                property string thumbSource: ""

                width: clipList.width
                height: 44
                onClicked: { Clipboard.copy(row.modelData.line); Bridge.closeIsland(); }

                Process {
                    id: thumbDecoder
                    command: ["sh", "-c",
                        "[ -f \"$2\" ] || { mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" | cliphist decode > \"$2\"; }",
                        "_", row.modelData.line, row.thumbPath]
                    onExited: {
                        row.thumbSource = "file://" + row.thumbPath;
                        Clipboard.markThumbReady(row.modelData.id);
                    }
                }

                Component.onCompleted: {
                    if (!row.modelData.isImage) return;
                    if (Clipboard.readyThumbs[row.modelData.id]) {
                        row.thumbSource = "file://" + row.thumbPath;
                    } else {
                        thumbDecoder.running = true;
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Rectangle {
                        visible: row.modelData.isImage
                        width: 32
                        height: 32
                        radius: Colors.radiusSmall
                        color: Colors.surfaceHigh
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.fill: parent
                            visible: row.thumbSource !== ""
                            source: row.thumbSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 16 - 8 - (row.modelData.isImage ? 40 : 0)
                        elide: Text.ElideRight
                        text: row.modelData.preview
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        font.pixelSize: 14
                        opacity: row.hovering ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            enabled: row.hovering
                            onClicked: Clipboard.remove(row.modelData.line)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: Clipboard.refresh()
}
