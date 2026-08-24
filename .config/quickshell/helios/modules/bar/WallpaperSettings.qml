import QtQuick
import Qt5Compat.GraphicalEffects
import "../../services"
import "../../components"

Item {
    id: root

    property string draftFolder: Wallpaper.folderPath

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        StyledText {
            width: parent.width
            font.bold: true
            text: "Wallpaper folder"
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: Colors.radiusSmall
            color: Colors.surfaceHigh

            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: 8
                color: Colors.text
                font.family: Config.fontFamily
                font.pixelSize: Config.fontSize
                clip: true
                text: root.draftFolder

                onTextChanged: root.draftFolder = text
                Keys.onReturnPressed: Wallpaper.setFolder(root.draftFolder)

                StyledText {
                    visible: input.text.length === 0
                    text: "~/Pictures/Wallpapers"
                    opacity: 0.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Rectangle {
            width: scanText.implicitWidth + 20
            height: 28
            radius: Colors.radiusSmall
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
                color: Colors.surfaceHigh
                opacity: scanHover.hovered ? 0.2 : 0
            }

            HoverHandler { id: scanHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpaper.setFolder(root.draftFolder)
            }
        }

        StyledText {
            visible: Wallpaper.folderPath !== "" && Wallpaper.images.length === 0
            text: "No images found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        StyledText {
            width: parent.width
            font.bold: true
            text: "Reveal animation"
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: Config.wallpaperRevealStyles

                Rectangle {
                    id: styleChip
                    required property string modelData
                    readonly property bool active: Config.wallpaperRevealStyle === modelData

                    width: chipText.implicitWidth + 16
                    height: 26
                    radius: Colors.radiusSmall
                    color: active ? Colors.accent : Colors.surfaceHigh
                    Behavior on color { ColorAnimation { duration: Config.animFast } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colors.surfaceHigh
                        opacity: styleChipHover.hovered && !styleChip.active ? 0.25 : 0
                    }

                    HoverHandler { id: styleChipHover }

                    StyledText {
                        id: chipText
                        anchors.centerIn: parent
                        text: styleChip.modelData
                        color: styleChip.active ? Colors.accentText : Colors.text
                        font.pixelSize: Config.fontSize - 2
                        font.capitalization: Font.Capitalize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.setWallpaperRevealStyle(styleChip.modelData)
                    }
                }
            }
        }

        Flickable {
            id: thumbFlick
            width: parent.width - 8
            height: Math.min(160, grid.implicitHeight)
            contentWidth: width
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: thumbFlick }

            // Fixed column count, cell width computed to fill the row edge-to-edge
            // (a Flow of fixed-size tiles left a dead gutter on the right instead).
            Grid {
                id: grid
                width: parent.width
                columns: 4
                spacing: 6

                readonly property real cellWidth: (width - (columns - 1) * spacing) / columns
                readonly property real cellHeight: cellWidth * 0.7

                Repeater {
                    model: Wallpaper.images

                    Item {
                        id: thumb
                        required property string modelData

                        width: grid.cellWidth
                        height: grid.cellHeight

                        readonly property bool selected: Wallpaper.path === modelData
                        readonly property int borderWidth: selected ? 2 : 0

                        Rectangle {
                            id: mask
                            anchors.fill: parent
                            anchors.margins: thumb.borderWidth
                            radius: Colors.radiusSmall
                            visible: false
                        }

                        Image {
                            id: img
                            anchors.fill: mask
                            source: "file://" + thumb.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: mask
                            source: img
                            maskSource: mask
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Colors.radiusSmall
                            color: "transparent"
                            border.width: thumb.borderWidth
                            border.color: Colors.accent
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Colors.radiusSmall
                            color: Colors.surfaceHigh
                            opacity: thumbHover.hovered && !thumb.selected ? 0.3 : 0
                        }

                        HoverHandler { id: thumbHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpaper.setPath(thumb.modelData)
                        }
                    }
                }
            }
        }
    }
}
