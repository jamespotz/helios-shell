import QtQuick
import Quickshell.Services.UPower
import "../../services"
import "../../components"

// Apple Control Center-inspired panel container. The tab bar uses a
// segmented-control aesthetic: a single rounded background with pill-shaped
// active indicator that slides between tabs. Content scrolls when tall.
Item {
    id: root

    readonly property int maxContentHeight: Config.islandMaxHeight - 120

    implicitWidth: pane.implicitWidth
    implicitHeight: tabs.height + pane.spacing + Math.min(panelLoader.implicitHeight, root.maxContentHeight)

    Column {
        id: pane
        width: Math.max(tabs.implicitWidth, panelLoader.implicitWidth)
        spacing: 14

        // ─── Tab bar: segmented control style ────────────────────────────
        Item {
            id: tabs
            width: pane.width
            implicitWidth: tabRow.implicitWidth + 8 + closeButton.width + 16
            height: 36

            // Background capsule for the tab row
            Rectangle {
                anchors.left: parent.left
                anchors.right: closeButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 32
                radius: 16
                color: Colors.surfaceHigh
                opacity: 0.4
            }

            Row {
                id: tabRow
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.right: closeButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: [
                        { tab: "volume", icon: "volume_up" },
                        { tab: "bluetooth", icon: "bluetooth" },
                        { tab: "wifi", icon: "wifi" },
                        { tab: "media", icon: "music_note" },
                        { tab: "clipboard", icon: "content_paste" },
                        { tab: "recorder", icon: "videocam" },
                        { tab: "weather", icon: "cloud" },
                        { tab: "activity", icon: "bar_chart" },
                        { tab: "wallpaper", icon: "wallpaper" },
                        { tab: "theme", icon: "palette" },
                        { tab: "power", icon: powerIcon },
                        { tab: "island", icon: "tune" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        readonly property bool active: Bridge.islandTab === modelData.tab

                        width: 30
                        height: 30
                        radius: 15
                        color: active ? Colors.accent : (tabHover.hovered ? Colors.overlay : "transparent")
                        opacity: active ? 1 : (tabHover.hovered ? 0.3 : 1)

                        Behavior on color { ColorAnimation { duration: Config.animFast } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: modelData.icon
                            font.pixelSize: 16
                            color: active ? Colors.accentText : Colors.text
                            opacity: active ? 1 : 0.8
                        }

                        HoverHandler { id: tabHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Bridge.setIslandTab(modelData.tab)
                        }
                    }
                }
            }

            // Close button — subtle, right-aligned
            Rectangle {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 14
                color: closeHover.hovered ? Colors.surfaceHigh : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "close"
                    font.pixelSize: 14
                    color: Colors.subtext
                }

                HoverHandler { id: closeHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bridge.closeIsland()
                }
            }
        }

        // ─── Scrollable content area ─────────────────────────────────────
        Item {
            id: scrollWrap
            width: pane.width
            height: Math.min(panelLoader.implicitHeight, root.maxContentHeight)

            readonly property bool showScrollbar: flick.contentHeight > flick.height

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.rightMargin: scrollWrap.showScrollbar ? 8 : 0
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
                        : Bridge.islandTab === "power" ? powerTab
                        : volumeTab
                }
            }

            // Scroll track — barely visible until content overflows
            Rectangle {
                visible: scrollWrap.showScrollbar
                width: 3
                radius: 1.5
                color: Colors.overlay
                opacity: 0.15
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
            }

            // Scroll thumb — accent-tinted, minimal
            Rectangle {
                visible: scrollWrap.showScrollbar
                width: 3
                radius: 1.5
                color: Colors.accent
                opacity: 0.6
                anchors.right: parent.right
                y: flick.contentHeight > 0 ? (flick.contentY / flick.contentHeight) * scrollWrap.height : 0
                height: flick.contentHeight > 0 ? Math.max(20, (flick.height / flick.contentHeight) * scrollWrap.height) : scrollWrap.height
            }
        }
    }

    // Power profile icon helper
    readonly property string powerIcon: PowerProfiles.profile === PowerProfile.PowerSaver ? "eco"
        : PowerProfiles.profile === PowerProfile.Performance ? "bolt" : "balance"

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
    Component { id: powerTab; PowerTab {} }
}
