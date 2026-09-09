pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../../components"

Column {
    id: root

    readonly property int cardWidth: Math.floor((width - 24) / 4)
    readonly property int cardHeight: 72
    spacing: 10

    Component.onCompleted: carousel.forceActiveFocus(Qt.TabFocusReason)

    Timer {
        id: videoFocusRestore
        interval: 150
        onTriggered: carousel.forceActiveFocus(Qt.TabFocusReason)
    }

    Row {
        width: parent.width

        StyledText {
            id: carouselTitle
            font.weight: Font.DemiBold
            text: "Wallpaper"
        }

        Item { width: parent.width - carouselTitle.implicitWidth - carouselCount.implicitWidth; height: 1 }

        StyledText {
            id: carouselCount
            visible: WallpaperLibrary.images.length > 0
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
            text: (carousel.currentIndex + 1) + " of " + WallpaperLibrary.images.length
        }
    }

    Item {
        id: carouselWrap
        width: parent.width
        height: WallpaperLibrary.images.length > 0 ? root.cardHeight : 0
        clip: true

        ListView {
            id: carousel
            anchors.fill: parent
            orientation: ListView.Horizontal
            model: WallpaperLibrary.images
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapOneItem
            keyNavigationWraps: false
            activeFocusOnTab: true
            focus: true
            Keys.priority: Keys.BeforeItem
            Keys.onLeftPressed: browse(currentIndex - 1)
            Keys.onRightPressed: browse(currentIndex + 1)

            // Not a plain `currentIndex: Math.max(0, ...)` binding — on a
            // fresh shell start this view can be built before WallpaperLibrary.path
            // and WallpaperLibrary.images (both loaded async, from disk and from a
            // `find` scan) have settled. The model going from empty to
            // populated makes the ListView itself write to currentIndex as
            // part of resetting for the new model, which silently breaks a
            // declarative binding here same as any other external write —
            // so once the real data arrives a moment later, nothing
            // recomputes it and the view is stuck showing index 0. Re-syncing
            // explicitly on every change (not just at creation) survives that.
            function syncToCurrent() {
                const idx = Math.max(0, WallpaperLibrary.images.indexOf(WallpaperLibrary.path));
                carousel.currentIndex = idx;
                // The model loads asynchronously. currentIndex may already be
                // zero before delegates exist, so always position after layout.
                Qt.callLater(() => {
                    if (carousel.count > 0)
                        carousel.positionViewAtIndex(carousel.currentIndex, ListView.Beginning);
                });
            }

            Component.onCompleted: syncToCurrent()

            Connections {
                target: WallpaperLibrary
                function onImagesChanged() { carousel.syncToCurrent() }
                function onPathChanged() { carousel.syncToCurrent() }
            }

            function browse(index) {
                if (index < 0 || index >= count) return;
                currentIndex = index;
                positionViewAtIndex(index, ListView.Center);
                forceActiveFocus(Qt.TabFocusReason);
            }

            function choose(index) {
                if (index < 0 || index >= count) return;
                const selectedPath = WallpaperLibrary.images[index];
                browse(index);
                WallpaperLibrary.setPath(selectedPath);
                Qt.callLater(() => forceActiveFocus(Qt.TabFocusReason));
                const extension = selectedPath.split(".").pop().toLowerCase();
                if (["mp4", "webm", "mkv", "mov"].includes(extension)) videoFocusRestore.restart();
            }

            delegate: Item {
                id: thumb
                required property string modelData
                required property int index

                width: root.cardWidth
                height: root.cardHeight

                readonly property bool selected: WallpaperLibrary.path === modelData
                readonly property bool browsed: ListView.isCurrentItem
                readonly property bool isVideoThumb: ["mp4", "webm", "mkv", "mov"].includes(modelData.split(".").pop().toLowerCase())
                readonly property string videoThumbPath: Quickshell.env("HOME") + "/.cache/helios/wallpaper-thumbs/" + modelData.replace(/[^A-Za-z0-9]/g, "_") + ".jpg"
                readonly property bool videoThumbReady: !!WallpaperLibrary.readyThumbnails[thumb.videoThumbPath]

                Component.onCompleted: {
                    if (thumb.isVideoThumb) WallpaperLibrary.requestThumbnail(thumb.modelData, thumb.videoThumbPath);
                }

                Item {
                    id: card
                    anchors.fill: parent

                    readonly property bool showPlaceholder: thumb.isVideoThumb && (!thumb.videoThumbReady || img.status === Image.Error)

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Colors.radiusSmall
                        color: Colors.surfaceHigh
                        clip: true

                        Image {
                            id: img
                            anchors.fill: parent
                            source: thumb.isVideoThumb
                                ? (thumb.videoThumbReady ? "file://" + thumb.videoThumbPath : "")
                                : "file://" + thumb.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: !card.showPlaceholder
                            sourceSize: Qt.size(root.cardWidth * 2, root.cardHeight * 2)
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: card.showPlaceholder
                            icon: "movie"
                            font.pixelSize: 22
                            opacity: 0.6
                        }
                    }

                    Rectangle {
                        visible: thumb.isVideoThumb && !card.showPlaceholder
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 20
                        height: 20
                        radius: 10
                        color: "black"
                        opacity: 0.6

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "movie"
                            filled: true
                            font.pixelSize: 11
                            color: "white"
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Colors.radiusSmall
                        color: thumb.browsed && !thumb.selected
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16)
                            : "transparent"
                        border.width: thumb.browsed ? 2 : thumb.selected ? 1 : 0
                        border.color: Colors.accent

                        Behavior on color { ColorAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                    }

                    MaterialIcon {
                        visible: thumb.selected
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        icon: "check_circle"
                        filled: true
                        font.pixelSize: 16
                        color: Colors.accent
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Colors.radiusSmall
                        color: Colors.overlay
                        opacity: thumbHover.hovered && !thumb.selected ? 0.2 : 0
                    }

                    HoverHandler { id: thumbHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            carousel.choose(thumb.index);
                            carousel.forceActiveFocus();
                        }
                    }
                }

                Keys.onReturnPressed: carousel.choose(thumb.index)
                Keys.onSpacePressed: carousel.choose(thumb.index)
            }
        }
    }

    Row {
        width: parent.width
        height: WallpaperLibrary.images.length > 0 ? 28 : 0
        visible: WallpaperLibrary.images.length > 0

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - previousButton.width - nextButton.width - 12
            elide: Text.ElideMiddle
            opacity: 0.75
            font.weight: Font.Medium
            font.pixelSize: Config.fontSize - 2
            text: carousel.currentIndex >= 0 && WallpaperLibrary.images[carousel.currentIndex]
                ? WallpaperLibrary.images[carousel.currentIndex].split("/").pop()
                : ""
        }

        IconButton {
            id: previousButton
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron_left"
            bounceOnHover: true
            enabled: carousel.currentIndex > 0
            onClicked: carousel.browse(carousel.currentIndex - 1)
        }

        IconButton {
            id: nextButton
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron_right"
            bounceOnHover: true
            enabled: carousel.currentIndex < carousel.count - 1
            onClicked: carousel.browse(carousel.currentIndex + 1)
        }
    }

}
