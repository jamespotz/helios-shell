pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services"
import "../../components"

Column {
    id: root

    required property var thumbnailHost
    readonly property int cardWidth: 250
    readonly property int cardHeight: 152
    spacing: 12

    Component.onCompleted: carousel.forceActiveFocus(Qt.TabFocusReason)

    Timer {
        id: videoFocusRestore
        interval: 150
        onTriggered: carousel.forceActiveFocus(Qt.TabFocusReason)
    }

    // --- Wallpaper carousel ---------------------------------------------
    StyledText {
        width: parent.width
        font.bold: true
        text: "Choose Wallpaper"
    }

    Item {
        id: carouselWrap
        width: parent.width
        height: Wallpaper.images.length > 0 ? 190 : 0
        clip: true

        ListView {
            id: carousel
            anchors.fill: parent
            orientation: ListView.Horizontal
            model: Wallpaper.images
            spacing: -42
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
                    anchors.centerIn: parent
                    width: root.cardWidth - 12
                    height: root.cardHeight
                    rotation: thumb.current ? -4 : (thumb.index < carousel.currentIndex ? -7 : 5)
                    scale: thumb.current ? 1 : 0.88
                    opacity: thumb.current ? 1 : 0.66
                    z: thumb.current ? 2 : 1

                    Behavior on rotation { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                    Rectangle {
                        visible: thumb.selected
                        anchors.fill: parent
                        anchors.margins: -5
                        radius: Colors.radiusLarge
                        color: Colors.accent
                        opacity: 0.25
                    }

                    readonly property bool showPlaceholder: thumb.isVideoThumb && (!thumb.videoThumbReady || img.status === Image.Error)

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Colors.radiusLarge
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
                        radius: Colors.radiusLarge
                        color: "transparent"
                        border.width: thumb.selected ? 2 : 0
                        border.color: Colors.accent
                    }

                    MaterialIcon {
                        visible: thumb.selected
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 7
                        icon: "check_circle"
                        filled: true
                        font.pixelSize: 18
                        color: Colors.accent
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Colors.radiusLarge
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
