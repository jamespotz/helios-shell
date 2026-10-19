pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../../components"

// Large preview over a grid of tiles. Hovering or arrowing onto a tile only
// previews it; click, Return, or Space sets it as the wallpaper.
Column {
    id: root

    readonly property int columns: 5
    readonly property int tileGap: 8
    readonly property int tileHeight: 48
    readonly property bool gridFocused: grid.activeFocus
    // Hover wins over the keyboard position, so pointing at a tile previews
    // it without moving the keyboard cursor.
    property int hoveredIndex: -1
    readonly property int previewIndex: hoveredIndex >= 0 ? hoveredIndex : grid.currentIndex
    readonly property string previewPath: WallpaperLibrary.images[root.previewIndex] || ""
    // Stills too large for Qt's image allocation limit (e.g. 12800x8000
    // upscales) fail to decode even with sourceSize — fall back to an
    // ffmpeg thumbnail like videos use.
    property var failedDecodes: ({})

    spacing: 10
    visible: WallpaperLibrary.images.length > 0

    function isVideo(path) {
        return ["mp4", "webm", "mkv", "mov"].includes(path.split(".").pop().toLowerCase());
    }

    function thumbPathFor(path) {
        return Quickshell.env("HOME") + "/.cache/helios/wallpaper-thumbs/" + path.replace(/[^A-Za-z0-9]/g, "_") + ".jpg";
    }

    function imageSource(path) {
        if (!path) return "";
        if (!root.isVideo(path) && !root.failedDecodes[path]) return "file://" + path;
        const thumbPath = root.thumbPathFor(path);
        return WallpaperLibrary.readyThumbnails[thumbPath] ? "file://" + thumbPath : "";
    }

    function markDecodeFailed(path) {
        if (root.failedDecodes[path]) return;
        const failed = Object.assign({}, root.failedDecodes);
        failed[path] = true;
        root.failedDecodes = failed;
        WallpaperLibrary.requestThumbnail(path, root.thumbPathFor(path));
    }

    Component.onCompleted: focusGridTimer.restart()

    // Bar establishes its Hyprland keyboard grab shortly after loading.
    // Focus after that handoff so arrow keys reach the grid.
    Timer {
        id: focusGridTimer
        interval: 120
        onTriggered: grid.forceActiveFocus(Qt.TabFocusReason)
    }

    Timer {
        id: videoFocusRestore
        interval: 150
        onTriggered: grid.forceActiveFocus(Qt.TabFocusReason)
    }

    // --- Preview ----------------------------------------------------------
    ClippingRectangle {
        id: preview
        width: parent.width
        height: 200
        radius: Colors.radiusLarge
        color: Colors.surfaceHigh

        readonly property string source: root.imageSource(root.previewPath)
        readonly property size decodeSize: Qt.size(width * 2, height * 2)

        // Crossfade: the back layer keeps the last image while the front one
        // loads the next, then fades in over it.
        onSourceChanged: {
            if (previewFront.source.toString() === source) return;
            previewBack.source = previewFront.source;
            previewFront.opacity = 0;
            previewFront.source = source;
        }

        Image {
            id: previewBack
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: preview.decodeSize
        }

        Image {
            id: previewFront
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: preview.decodeSize
            opacity: 0
            onStatusChanged: {
                if (status === Image.Ready) opacity = 1;
                else if (status === Image.Error && !root.isVideo(root.previewPath)) root.markDecodeFailed(root.previewPath);
            }

            Behavior on opacity { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: preview.source === ""
            icon: root.isVideo(root.previewPath) ? "movie" : "image"
            font.pixelSize: 28
            opacity: 0.6
        }
    }

    // --- Grid ---------------------------------------------------------------
    GridView {
        id: grid
        width: parent.width
        // Two rows, plus a sliver of the third so it reads as scrollable.
        height: Math.min(Math.ceil(count / root.columns), 2.4) * cellHeight
        cellWidth: width / root.columns
        cellHeight: root.tileHeight + root.tileGap
        model: WallpaperLibrary.images
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: true
        focus: true
        keyNavigationEnabled: false
        Keys.priority: Keys.BeforeItem
        Keys.onLeftPressed: browse(currentIndex - 1)
        Keys.onRightPressed: browse(currentIndex + 1)
        Keys.onUpPressed: browse(currentIndex - root.columns)
        Keys.onDownPressed: browse(currentIndex + root.columns)
        Keys.onReturnPressed: choose(currentIndex)
        Keys.onSpacePressed: choose(currentIndex)

        // Not a plain `currentIndex: Math.max(0, ...)` binding — on a
        // fresh shell start this view can be built before WallpaperLibrary.path
        // and WallpaperLibrary.images (both loaded async, from disk and from a
        // `find` scan) have settled. The model going from empty to
        // populated makes the GridView itself write to currentIndex as
        // part of resetting for the new model, which silently breaks a
        // declarative binding here same as any other external write —
        // so once the real data arrives a moment later, nothing
        // recomputes it and the view is stuck showing index 0. Re-syncing
        // explicitly on every change (not just at creation) survives that.
        function syncToCurrent() {
            const idx = Math.max(0, WallpaperLibrary.images.indexOf(WallpaperLibrary.path));
            grid.currentIndex = idx;
            // The model loads asynchronously. currentIndex may already be
            // zero before delegates exist, so always position after layout.
            Qt.callLater(() => {
                if (grid.count > 0)
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
            });
        }

        Component.onCompleted: syncToCurrent()

        Connections {
            target: WallpaperLibrary
            function onImagesChanged() { grid.syncToCurrent() }
            function onPathChanged() { grid.syncToCurrent() }
        }

        function browse(index) {
            if (index < 0 || index >= count) return;
            currentIndex = index;
            positionViewAtIndex(index, GridView.Contain);
            forceActiveFocus(Qt.TabFocusReason);
        }

        function choose(index) {
            if (index < 0 || index >= count) return;
            const selectedPath = WallpaperLibrary.images[index];
            browse(index);
            if (selectedPath === WallpaperLibrary.path) return;
            AlertSounds.play("tap");
            Wallpaper.select(selectedPath);
            Qt.callLater(() => forceActiveFocus(Qt.TabFocusReason));
            if (root.isVideo(selectedPath)) videoFocusRestore.restart();
        }

        delegate: Item {
            id: tile
            required property string modelData
            required property int index

            width: grid.cellWidth
            height: grid.cellHeight

            readonly property bool selected: WallpaperLibrary.path === modelData
            readonly property bool browsed: tile.index === grid.currentIndex
            readonly property bool isVideoTile: root.isVideo(modelData)
            readonly property string source: root.imageSource(modelData)

            Component.onCompleted: {
                if (tile.isVideoTile) WallpaperLibrary.requestThumbnail(tile.modelData, root.thumbPathFor(tile.modelData));
            }

            Item {
                id: card
                x: root.tileGap / 2
                y: root.tileGap / 2
                width: parent.width - root.tileGap
                height: root.tileHeight

                readonly property bool showPlaceholder: tile.source === "" || img.status === Image.Error

                // Selected: accent ring with a gap. Keyboard position: a
                // quieter text-colored ring, only while the grid has focus.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: Colors.radiusSmall + 3
                    color: "transparent"
                    border.width: tile.selected || (tile.browsed && grid.activeFocus) ? 2 : 0
                    border.color: tile.selected ? Colors.accent : Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.5)
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Colors.radiusSmall
                    color: Colors.surfaceHigh

                    Image {
                        id: img
                        anchors.fill: parent
                        source: tile.source
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: !card.showPlaceholder
                        sourceSize: Qt.size(card.width * 2, card.height * 2)
                        onStatusChanged: {
                            if (status === Image.Error && !tile.isVideoTile) root.markDecodeFailed(tile.modelData);
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: card.showPlaceholder
                        icon: tile.isVideoTile ? "movie" : "image"
                        font.pixelSize: 16
                        opacity: 0.6
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Colors.overlay
                        opacity: tileMouse.containsMouse && !tile.selected ? 0.2 : 0

                        Behavior on opacity { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                    }
                }

                MaterialIcon {
                    visible: tile.isVideoTile && !card.showPlaceholder
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    icon: "movie"
                    filled: true
                    font.pixelSize: 11
                    color: "white"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                }

                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) root.hoveredIndex = tile.index;
                        else if (root.hoveredIndex === tile.index) root.hoveredIndex = -1;
                    }
                    onClicked: grid.choose(tile.index)
                }
            }
        }
    }
}
