import QtQuick
import Quickshell.Io
import "../../services"
import "../../components"

// Card carousel leads wallpaper selection. Folder path stays behind a
// collapsed disclosure row so routine selection remains focused.
Item {
    id: root

    property string draftFolder: WallpaperLibrary.folderPath
    property bool folderEditorOpen: false

    implicitWidth: 440
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 16

        WallpaperCarousel {
            width: parent.width
        }

        // --- Folder (collapsed disclosure row) --------------------------------
        HoverRow {
            width: parent.width
            height: 46
            highlighted: root.folderEditorOpen
            onClicked: root.folderEditorOpen = !root.folderEditorOpen

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                MaterialIcon { icon: "folder"; font.pixelSize: 15; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    width: parent.width - 15 - 15 - 16
                    elide: Text.ElideMiddle
                    opacity: 0.8
                    text: WallpaperLibrary.folderPath || "No folder set"
                    anchors.verticalCenter: parent.verticalCenter
                }
                MaterialIcon {
                    icon: root.folderEditorOpen ? "expand_less" : "chevron_right"
                    font.pixelSize: 15
                    opacity: 0.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8
            visible: root.folderEditorOpen

            Rectangle {
                width: parent.width
                height: 36
                radius: height / 2
                color: Colors.surfaceHigh

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    color: Colors.text
                    font.family: Config.fontFamily
                    font.pixelSize: Config.fontSize
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.draftFolder

                    onTextChanged: root.draftFolder = text
                    Keys.onReturnPressed: WallpaperLibrary.setFolder(root.draftFolder)

                    StyledText {
                        visible: input.text.length === 0
                        text: "~/Pictures/Wallpapers"
                        opacity: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                width: scanText.implicitWidth + 24
                height: 30
                radius: height / 2
                color: Colors.accent

                StyledText {
                    id: scanText
                    anchors.centerIn: parent
                    text: "Scan"
                    color: Colors.accentText
                    font.bold: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colors.overlay
                    opacity: scanHover.hovered ? 0.2 : 0
                }

                HoverHandler { id: scanHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WallpaperLibrary.setFolder(root.draftFolder)
                }
            }
        }

        StyledText {
            visible: WallpaperLibrary.folderPath !== "" && WallpaperLibrary.images.length === 0
            text: "No images found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        // --- Transition ----------------------------------------------------
        StyledText {
            width: parent.width
            font.weight: Font.DemiBold
            text: "Transition"
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: Config.wallpaperTransitionStyles

                Chip {
                    required property string modelData
                    active: Config.wallpaperTransitionStyle === modelData
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    onClicked: Config.setWallpaperTransitionStyle(modelData)
                }
            }
        }

    }
}
