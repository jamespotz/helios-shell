import QtQuick
import Quickshell.Io
import "../../services"
import "../../components"

// Card carousel leads wallpaper selection. Folder path stays behind a
// collapsed disclosure row so routine selection remains focused.
Item {
    id: root

    property string draftFolder: Wallpaper.folderPath
    property bool folderEditorOpen: false
    property var thumbnailQueue: []
    property var readyThumbnails: ({})

    // Loader recreates this tab each time it's opened, so pick up any
    // files added/removed on disk since last time — but only if a folder
    // is actually configured, no point scanning nothing.
    Component.onCompleted: if (Wallpaper.folderPath) Wallpaper.scanFolder()

    function requestThumbnail(sourcePath, outputPath) {
        if (root.readyThumbnails[outputPath] || thumbnailGenerator.outputPath === outputPath
                || root.thumbnailQueue.some(job => job.outputPath === outputPath)) return;
        root.thumbnailQueue = root.thumbnailQueue.concat([{
            sourcePath: sourcePath,
            outputPath: outputPath
        }]);
        root.startNextThumbnail();
    }

    function startNextThumbnail() {
        if (thumbnailGenerator.running || root.thumbnailQueue.length === 0) return;
        const job = root.thumbnailQueue[0];
        root.thumbnailQueue = root.thumbnailQueue.slice(1);
        thumbnailGenerator.outputPath = job.outputPath;
        thumbnailGenerator.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\" && { [ -f \"$2\" ] || "
                + "ffmpeg -y -loglevel error -ss 00:00:00.5 -i \"$1\" -frames:v 1 -vf scale=320:-1 \"$2\"; }",
            "_", job.sourcePath, job.outputPath];
        thumbnailGenerator.running = true;
    }

    Process {
        id: thumbnailGenerator
        property string outputPath: ""
        onExited: exitCode => {
            if (exitCode === 0)
                root.readyThumbnails = Object.assign({}, root.readyThumbnails, { [outputPath]: true });
            root.startNextThumbnail();
        }
    }

    implicitWidth: 430
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 12

        WallpaperCarousel {
            width: parent.width
            thumbnailHost: root
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

        // --- Transition ----------------------------------------------------
        StyledText {
            width: parent.width
            font.bold: true
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
