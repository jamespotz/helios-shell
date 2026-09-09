pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../../components"

Column {
    id: root

    required property var thumbnailHost
    // Landscape cells matching actual wallpaper aspect ratio (portrait cells
    // cropped desktop wallpapers down to an unrecognizable sliver), tightly
    // packed, bottom-aligned. The current card grows via `scale` anchored to
    // the shared bottom edge (see delegate below).
    readonly property int cardWidth: 130
    readonly property int cardHeight: 78
    spacing: 12

    Component.onCompleted: carousel.forceActiveFocus(Qt.TabFocusReason)

    Timer {
        id: videoFocusRestore
        interval: 150
        onTriggered: carousel.forceActiveFocus(Qt.TabFocusReason)
    }

    // --- Wallpaper carousel ---------------------------------------------
    Row {
        width: parent.width

        StyledText {
            id: carouselTitle
            font.bold: true
            text: "Choose Wallpaper"
        }

        Item { width: parent.width - carouselTitle.implicitWidth - carouselCount.implicitWidth; height: 1 }

        StyledText {
            id: carouselCount
            visible: Wallpaper.images.length > 0
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
            text: (carousel.currentIndex + 1) + " / " + Wallpaper.images.length
        }
    }

    Item {
        id: carouselWrap
        width: parent.width
        height: Wallpaper.images.length > 0 ? 145 : 0
        clip: true

        ListView {
            id: carousel
            anchors.fill: parent
            orientation: ListView.Horizontal
            model: Wallpaper.images
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - root.cardWidth) / 2
            preferredHighlightEnd: preferredHighlightBegin + root.cardWidth
            keyNavigationWraps: false
            activeFocusOnTab: true
            focus: true
            Keys.priority: Keys.BeforeItem
            Keys.onLeftPressed: choose(currentIndex - 1)
            Keys.onRightPressed: choose(currentIndex + 1)
            currentIndex: Math.max(0, Wallpaper.images.indexOf(Wallpaper.path))

            function choose(index) {
                if (index < 0 || index >= count) return;
                currentIndex = index;
                positionViewAtIndex(index, ListView.Center);
                Wallpaper.setPath(Wallpaper.images[index]);
                Qt.callLater(() => forceActiveFocus(Qt.TabFocusReason));
                const extension = Wallpaper.images[index].split(".").pop().toLowerCase();
                if (["mp4", "webm", "mkv", "mov"].includes(extension)) videoFocusRestore.restart();
            }

            delegate: Item {
                id: thumb
                required property string modelData
                required property int index

                width: root.cardWidth
                height: carousel.height
                z: current ? 2 : 1
                activeFocusOnTab: true

                readonly property bool selected: Wallpaper.path === modelData
                readonly property bool isVideoThumb: ["mp4", "webm", "mkv", "mov"].includes(modelData.split(".").pop().toLowerCase())
                readonly property string videoThumbPath: Quickshell.env("HOME") + "/.cache/helios/wallpaper-thumbs/" + modelData.replace(/[^A-Za-z0-9]/g, "_") + ".jpg"
                readonly property bool videoThumbReady: !!root.thumbnailHost.readyThumbnails[thumb.videoThumbPath]
                readonly property bool current: ListView.isCurrentItem

                Component.onCompleted: {
                    if (thumb.isVideoThumb) root.thumbnailHost.requestThumbnail(thumb.modelData, thumb.videoThumbPath);
                }

                Item {
                    id: card
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    transformOrigin: Item.Bottom
                    width: root.cardWidth
                    height: root.cardHeight
                    // Flat: every non-current card stays the exact same
                    // size (uniform shelf), only the current one grows —
                    // per-distance shrinking left uneven gaps between
                    // neighbors instead of a tight, even filmstrip.
                    scale: thumb.current ? 1.3 : 1
                    z: thumb.current ? 2 : 1

                    Behavior on scale { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }

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
                            sourceSize: Qt.size(card.width * 2, card.height * 2)
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
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 7
                        width: 22
                        height: 22
                        radius: 11
                        color: "black"
                        opacity: 0.6

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
                        border.width: thumb.selected ? 1 : 0
                        border.color: Colors.accent
                    }

                    MaterialIcon {
                        visible: thumb.selected
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 5
                        icon: "check_circle"
                        filled: true
                        font.pixelSize: 13
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

                // Filename caption for the current card — sits outside
                // `card` (not a child of it) so it isn't itself scaled up
                // and blurred by card's transform; position is computed from
                // card's known base size + scale instead. Card is now
                // bottom-anchored and grows upward, so the caption sits
                // above its (moving) top edge rather than below it.
                Rectangle {
                    id: caption
                    visible: thumb.current
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - card.height * card.scale - height - 6
                    width: Math.min(root.cardWidth * 2, captionText.implicitWidth + 16)
                    height: 20
                    radius: 6
                    color: "black"
                    opacity: 0.55

                    StyledText {
                        id: captionText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, root.cardWidth * 2 - 16)
                        elide: Text.ElideMiddle
                        color: "white"
                        font.pixelSize: Config.fontSize - 3
                        text: thumb.modelData.split("/").pop()
                    }
                }

                Keys.onReturnPressed: carousel.choose(thumb.index)
                Keys.onSpacePressed: carousel.choose(thumb.index)
            }
        }

        // Fades the outermost thumbnails into the panel background instead
        // of hard-cutting them at the viewport edge — reads as the filmstrip
        // receding into the distance rather than just being clipped.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 28
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Colors.surface }
                GradientStop { position: 1; color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0) }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 28
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0) }
                GradientStop { position: 1; color: Colors.surface }
            }
        }

        IconButton {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron_left"
            enabled: carousel.currentIndex > 0
            opacity: enabled ? 1 : 0.3
            onClicked: carousel.choose(carousel.currentIndex - 1)
            onActiveFocusChanged: if (activeFocus) carousel.forceActiveFocus(Qt.TabFocusReason)
        }

        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            icon: "chevron_right"
            enabled: carousel.currentIndex < carousel.count - 1
            opacity: enabled ? 1 : 0.3
            onClicked: carousel.choose(carousel.currentIndex + 1)
            onActiveFocusChanged: if (activeFocus) carousel.forceActiveFocus(Qt.TabFocusReason)
        }
    }

}
