import QtQuick
import Qt5Compat.GraphicalEffects
import "../../services"
import "../../components"

// macOS Wallpaper-picker-inspired layout: a big preview of the current
// wallpaper up top, the folder path tucked behind a collapsed disclosure row
// (power-user config, not the default focus), then reveal-style pills and a
// bigger, fewer-columns thumbnail grid than before.
Item {
    id: root

    property string draftFolder: Wallpaper.folderPath
    property bool folderEditorOpen: false

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 12

        // --- Hero preview ----------------------------------------------------
        Rectangle {
            width: parent.width
            height: 160
            radius: Colors.radiusLarge
            color: Colors.surfaceHigh
            clip: true

            Image {
                anchors.fill: parent
                visible: Wallpaper.path !== ""
                source: Wallpaper.path !== "" ? "file://" + Wallpaper.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: Wallpaper.path === ""
                icon: "wallpaper"
                font.pixelSize: 36
                opacity: 0.4
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 32
                visible: Wallpaper.path !== ""

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideMiddle
                    font.pixelSize: Config.fontSize - 2
                    text: Wallpaper.path.split("/").pop()
                }
            }
        }

        // --- Folder (collapsed disclosure row) --------------------------------
        HoverRow {
            width: parent.width
            height: 36
            highlighted: root.folderEditorOpen
            onClicked: root.folderEditorOpen = !root.folderEditorOpen

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                MaterialIcon { icon: "folder"; font.pixelSize: 15; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    width: parent.width - 15 - 15 - 16
                    elide: Text.ElideMiddle
                    opacity: 0.8
                    text: Wallpaper.folderPath || "No folder set"
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
                    onClicked: Wallpaper.setFolder(root.draftFolder)
                }
            }
        }

        StyledText {
            visible: Wallpaper.folderPath !== "" && Wallpaper.images.length === 0
            text: "No images found"
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
        }

        // --- Reveal animation --------------------------------------------------
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

                Chip {
                    required property string modelData
                    active: Config.wallpaperRevealStyle === modelData
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    onClicked: Config.setWallpaperRevealStyle(modelData)
                }
            }
        }

        // --- Thumbnail grid ------------------------------------------------
        StyledText {
            width: parent.width
            font.bold: true
            text: "Choose Wallpaper"
        }

        Flickable {
            id: thumbFlick
            width: parent.width - 8
            height: Math.min(200, grid.implicitHeight)
            contentWidth: width
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: thumbFlick }

            // Fewer, bigger tiles than before (3 columns, not 4) — reads
            // closer to macOS's own wallpaper picker than a dense grid.
            Grid {
                id: grid
                width: parent.width
                columns: 3
                spacing: 8

                readonly property real cellWidth: (width - (columns - 1) * spacing) / columns
                readonly property real cellHeight: cellWidth * 0.62

                Repeater {
                    model: Wallpaper.images

                    Item {
                        id: thumb
                        required property string modelData

                        width: grid.cellWidth
                        height: grid.cellHeight

                        readonly property bool selected: Wallpaper.path === modelData

                        // Soft accent glow behind the selected tile — same
                        // "today" halo language used everywhere else, instead
                        // of relying on the hard border alone.
                        Rectangle {
                            visible: thumb.selected
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: Colors.radiusLarge
                            color: Colors.accent
                            opacity: 0.25
                        }

                        Rectangle {
                            id: mask
                            anchors.fill: parent
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
                            sourceSize: Qt.size(grid.cellWidth * 2, grid.cellHeight * 2)
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
                            border.width: thumb.selected ? 2 : 0
                            border.color: Colors.accent
                        }

                        MaterialIcon {
                            visible: thumb.selected
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            icon: "check_circle"
                            filled: true
                            font.pixelSize: 16
                            color: Colors.accent
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Colors.radiusSmall
                            color: Colors.overlay
                            opacity: thumbHover.hovered && !thumb.selected ? 0.25 : 0
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
