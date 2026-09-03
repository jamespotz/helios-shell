import QtQuick
import QtMultimedia
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
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
    property var thumbnailQueue: []
    property var readyThumbnails: ({})

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

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 12

        // --- Hero preview ----------------------------------------------------
        ClippingRectangle {
            width: parent.width
            height: 160
            radius: Colors.radiusLarge
            color: Colors.surfaceHigh
            clip: true

            Image {
                anchors.fill: parent
                visible: Wallpaper.path !== "" && !Wallpaper.isVideo
                source: Wallpaper.path !== "" ? "file://" + Wallpaper.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // videoOutput is set on MediaPlayer, not source on VideoOutput —
            // this build's VideoOutput has no `source` property (see
            // modules/wallpaper/Wallpaper.qml).
            MediaPlayer {
                id: previewPlayer
                source: Wallpaper.isVideo ? Wallpaper.source : ""
                loops: MediaPlayer.Infinite
                audioOutput: null
                videoOutput: previewVideo

                function sync() { Wallpaper.isVideo ? play() : pause() }
                onSourceChanged: sync()
                Component.onCompleted: sync()
            }

            VideoOutput {
                id: previewVideo
                anchors.fill: parent
                visible: Wallpaper.isVideo
                fillMode: VideoOutput.PreserveAspectCrop
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

        // Wrapped so ScrollIndicator (anchors to its target's edges) is a
        // sibling of the Flickable rather than a child inside it; Qt
        // doesn't support a child anchoring to the Flickable it's inside
        // (see components/ScrollIndicator.qml).
        Item {
            id: thumbFlickWrap
            width: parent.width
            height: Math.min(200, grid.implicitHeight)

            Flickable {
                id: thumbFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: grid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

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
                            readonly property bool isVideoThumb: ["mp4", "webm", "mkv", "mov"].includes(modelData.split(".").pop().toLowerCase())
                            readonly property string videoThumbPath: Quickshell.env("HOME") + "/.cache/helios/wallpaper-thumbs/" + modelData.replace(/[^A-Za-z0-9]/g, "_") + ".jpg"
                            readonly property bool videoThumbReady: !!root.readyThumbnails[thumb.videoThumbPath]

                            Component.onCompleted: {
                                if (thumb.isVideoThumb) root.requestThumbnail(thumb.modelData, thumb.videoThumbPath);
                            }

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
                                layer.enabled: true
                            }

                            readonly property bool showPlaceholder: thumb.isVideoThumb && (!thumb.videoThumbReady || img.status === Image.Error)

                            Image {
                                id: img
                                anchors.fill: mask
                                source: thumb.isVideoThumb
                                    ? (thumb.videoThumbReady ? "file://" + thumb.videoThumbPath : "")
                                    : "file://" + thumb.modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: false
                                sourceSize: Qt.size(grid.cellWidth * 2, grid.cellHeight * 2)
                            }

                            MultiEffect {
                                anchors.fill: mask
                                source: img
                                maskEnabled: true
                                maskSource: mask
                                visible: !thumb.showPlaceholder
                            }

                            // Fallback while the frame grab runs (or if ffmpeg is
                            // unavailable/fails) — same placeholder as before.
                            Rectangle {
                                anchors.fill: parent
                                radius: Colors.radiusSmall
                                color: Colors.surfaceHigh
                                visible: thumb.showPlaceholder

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    icon: "movie"
                                    font.pixelSize: 22
                                    opacity: 0.6
                                }
                            }

                            // Video indicator — the thumbnail alone (a still
                            // frame) can't tell photo and video apart.
                            Rectangle {
                                visible: thumb.isVideoThumb
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 4
                                width: 20
                                height: 20
                                radius: 10
                                color: "black"
                                opacity: 0.55

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    icon: "movie"
                                    filled: true
                                    font.pixelSize: 12
                                    color: "white"
                                }
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

            ScrollIndicator { target: thumbFlick }
        }
    }
}
