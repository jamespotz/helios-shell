import QtQuick
import "../../services"
import "../../components"

// Hosts the volume/Bluetooth/Wifi tab content with a small header so the
// panel modes can switch between each other without closing the island.
Item {
    id: root

    // Keeps any tab's content within the island's fixed max surface height
    // (Config.islandMaxHeight) — without this a tall tab (e.g. Island
    // settings' widget list) gets hard-clipped by the real Wayland surface
    // edge instead of scrolling. Derived from islandMaxHeight (rather than a
    // guessed constant) minus a generous flat budget for the tab header,
    // spacing, and Bar.qml's own padding, so it stays correct even if those
    // change.
    readonly property int maxContentHeight: Config.islandMaxHeight - 140

    implicitWidth: pane.implicitWidth
    // tabs.height, not tabs.implicitHeight — that Item only ever binds an
    // explicit `height` (from leftTabs.implicitHeight), so its own
    // implicitHeight stays 0 and silently undercounts the header here.
    implicitHeight: tabs.height + pane.spacing + Math.min(panelLoader.implicitHeight, root.maxContentHeight)

    Column {
        id: pane
        width: Math.max(tabs.implicitWidth, panelLoader.implicitWidth)
        spacing: 12

        Item {
            id: tabs
            width: pane.width
            implicitWidth: leftTabs.implicitWidth + closeButton.implicitWidth
            height: leftTabs.implicitHeight

            Row {
                id: leftTabs
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IconButton {
                    icon: "volume_up"
                    active: Bridge.islandTab === "volume"
                    onClicked: Bridge.setIslandTab("volume")
                }
                IconButton {
                    icon: "bluetooth"
                    active: Bridge.islandTab === "bluetooth"
                    onClicked: Bridge.setIslandTab("bluetooth")
                }
                IconButton {
                    icon: "wifi"
                    active: Bridge.islandTab === "wifi"
                    onClicked: Bridge.setIslandTab("wifi")
                }
                IconButton {
                    icon: "music_note"
                    active: Bridge.islandTab === "media"
                    onClicked: Bridge.setIslandTab("media")
                }
                IconButton {
                    icon: "content_paste"
                    active: Bridge.islandTab === "clipboard"
                    onClicked: Bridge.setIslandTab("clipboard")
                }
                IconButton {
                    icon: "videocam"
                    active: Bridge.islandTab === "recorder"
                    onClicked: Bridge.setIslandTab("recorder")
                }
                IconButton {
                    icon: "cloud"
                    active: Bridge.islandTab === "weather"
                    onClicked: Bridge.setIslandTab("weather")
                }
                IconButton {
                    icon: "bar_chart"
                    active: Bridge.islandTab === "activity"
                    onClicked: Bridge.setIslandTab("activity")
                }
                IconButton {
                    icon: "wallpaper"
                    active: Bridge.islandTab === "wallpaper"
                    onClicked: Bridge.setIslandTab("wallpaper")
                }
                IconButton {
                    icon: "palette"
                    active: Bridge.islandTab === "theme"
                    onClicked: Bridge.setIslandTab("theme")
                }
                IconButton {
                    icon: "tune"
                    active: Bridge.islandTab === "island"
                    onClicked: Bridge.setIslandTab("island")
                }
            }

            IconButton {
                id: closeButton
                icon: "close"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Bridge.closeIsland()
            }
        }

        Item {
            id: scrollWrap
            width: pane.width
            height: Math.min(panelLoader.implicitHeight, root.maxContentHeight)

            readonly property bool showScrollbar: flick.contentHeight > flick.height

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.rightMargin: scrollWrap.showScrollbar ? 10 : 0
                contentWidth: width
                contentHeight: panelLoader.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Loader {
                    id: panelLoader
                    width: flick.width
                    sourceComponent: Bridge.islandTab === "bluetooth" ? bluetoothTab
                        : Bridge.islandTab === "wifi" ? wifiTab
                        : Bridge.islandTab === "media" ? mediaTab
                        : Bridge.islandTab === "clipboard" ? clipboardTab
                        : Bridge.islandTab === "recorder" ? recorderTab
                        : Bridge.islandTab === "weather" ? weatherTab
                        : Bridge.islandTab === "calendar" ? weatherTab
                        : Bridge.islandTab === "activity" ? activityTab
                        : Bridge.islandTab === "wallpaper" ? wallpaperTab
                        : Bridge.islandTab === "theme" ? themeTab
                        : Bridge.islandTab === "island" ? islandTab
                        : volumeTab
                }
            }

            Rectangle {
                visible: scrollWrap.showScrollbar
                width: 4
                radius: 2
                color: Colors.overlay
                opacity: 0.3
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
            }

            Rectangle {
                visible: scrollWrap.showScrollbar
                width: 4
                radius: 2
                color: Colors.accent
                anchors.right: parent.right
                y: flick.contentHeight > 0 ? (flick.contentY / flick.contentHeight) * scrollWrap.height : 0
                height: flick.contentHeight > 0 ? Math.max(24, (flick.height / flick.contentHeight) * scrollWrap.height) : scrollWrap.height
            }
        }
    }

    Component { id: volumeTab; VolumeTab {} }
    Component { id: bluetoothTab; BluetoothTab {} }
    Component { id: wifiTab; WifiTab {} }
    Component { id: mediaTab; MediaCard {} }
    Component { id: clipboardTab; ClipboardTab {} }
    Component { id: recorderTab; ScreenRecorderTab {} }
    Component { id: weatherTab; WeatherPanel {} }
    Component { id: activityTab; ActivityTab {} }
    Component { id: wallpaperTab; WallpaperSettings {} }
    Component { id: themeTab; ThemeSettings {} }
    Component { id: islandTab; IslandSettings {} }
}
