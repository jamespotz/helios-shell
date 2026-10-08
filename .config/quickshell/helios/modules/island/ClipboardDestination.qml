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

                MaterialIcon { anchors.verticalCenter: parent.verticalCenter; icon: "content_paste"; color: Colors.accent }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    font.weight: Font.DemiBold
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "· " + Clipboard.items.length + " items"
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
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

        StyledText { visible: Clipboard.error.length > 0; width: parent.width; wrapMode: Text.Wrap; text: Clipboard.error; color: Colors.danger }
        StyledText { text: qsTr("Favorites"); font.weight: Font.DemiBold }
        StyledText { visible: Clipboard.favorites.length === 0; text: qsTr("Pin text from history to keep it here"); color: Colors.subtext; font.pixelSize: Config.fontSize - 2 }
        Item {
            width: parent.width
            visible: Clipboard.favorites.length > 0
            height: Math.min(184, Clipboard.favorites.length * 46)
            ListView {
                id: favoriteList
                anchors.fill: parent
                clip: true
                model: Clipboard.favorites
                boundsBehavior: Flickable.StopAtBounds
                delegate: HoverRow {
                    id: favoriteRow
                    required property var modelData
                    width: favoriteList.width
                    height: 44
                    label: qsTr("Copy favorite: %1").arg(modelData.preview)
                    enabled: !Clipboard.favoriteBusy
                    onClicked: Clipboard.copyFavorite(modelData.id)
                    StyledText { anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; text: favoriteRow.modelData.preview; elide: Text.ElideRight }
                    IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; icon: "push_pin"; active: true; label: qsTr("Unpin text"); onClicked: Clipboard.unpin(favoriteRow.modelData.id) }
                }
            }
            ScrollIndicator { target: favoriteList }
        }
        StyledText { text: qsTr("History"); font.weight: Font.DemiBold }

        StyledText {
            visible: Clipboard.items.length === 0
            text: "No clipboard history"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        // Wraps the ListView so ScrollIndicator — which anchors to its
        // target's edges — is a sibling of the Flickable rather than a
        // child inside it; Qt doesn't support a child anchoring to the
        // Flickable it's inside (see components/ScrollIndicator.qml).
        Item {
            id: clipListWrap
            width: parent.width
            visible: Clipboard.items.length > 0
            height: Math.min(280, Math.max(0, Clipboard.items.length * 46))

            ListView {
                id: clipList
                anchors.fill: parent
                clip: true
                spacing: 2
                model: Clipboard.items
                boundsBehavior: Flickable.StopAtBounds

                delegate: HoverRow {
                    id: row
                    required property var modelData
                    required property int index

                    readonly property string thumbPath: Quickshell.env("HOME") + "/.cache/helios/clip-thumbs/" + modelData.id + ".img"
                    property string thumbSource: ""

                    width: clipList.width
                    height: 44
                    label: qsTr("Copy clipboard entry: %1").arg(modelData.preview)
                    onClicked: { Clipboard.copy(row.modelData.line); IslandNavigation.close(); }

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
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 68 - 16 - (row.modelData.isImage ? 40 : 0)
                            elide: Text.ElideRight
                            text: row.modelData.preview
                        }

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "push_pin"
                            label: qsTr("Pin text")
                            enabled: !row.modelData.isImage && !Clipboard.favoriteBusy
                            iconSize: 14
                            onClicked: Clipboard.pin(row.modelData.line)
                        }
                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "close"
                            label: qsTr("Delete history entry")
                            iconSize: 14
                            onClicked: Clipboard.remove(row.modelData.line)
                        }
                    }
                }
            }

            ScrollIndicator { target: clipList }
        }
    }

    Component.onCompleted: Clipboard.refresh()
}
