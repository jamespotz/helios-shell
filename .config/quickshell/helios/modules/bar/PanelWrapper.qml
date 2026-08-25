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
                radius: Colors.radiusLarge
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
                        { tab: "screenshot", icon: "screenshot_monitor" },
                        { tab: "weather", icon: "cloud" },
                        { tab: "activity", icon: "bar_chart" },
                        { tab: "notifications", icon: "history" },
                        { tab: "nightlight", icon: "nightlight" },
                        { tab: "display", icon: "monitor" },
                        { tab: "idle", icon: "bedtime" },
                        { tab: "wallpaper", icon: "wallpaper" },
                        { tab: "theme", icon: "palette" },
                        { tab: "power", icon: powerIcon },
                        { tab: "island", icon: "tune" }
                    ]

                    delegate: IconButton {
                        required property var modelData
                        required property int index

                        active: Bridge.islandTab === modelData.tab
                        icon: modelData.icon
                        onClicked: Bridge.setIslandTab(modelData.tab)
                    }
                }
            }

            // Close button — subtle, right-aligned
            IconButton {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                icon: "close"
                iconSize: 14
                iconColor: Colors.subtext
                onClicked: Bridge.closeIsland()
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
                        : Bridge.islandTab === "screenshot" ? screenshotTab
                        : Bridge.islandTab === "weather" ? weatherTab
                        : Bridge.islandTab === "calendar" ? weatherTab
                        : Bridge.islandTab === "activity" ? activityTab
                        : Bridge.islandTab === "notifications" ? notificationsTab
                        : Bridge.islandTab === "nightlight" ? nightlightTab
                        : Bridge.islandTab === "display" ? displayTab
                        : Bridge.islandTab === "idle" ? idleTab
                        : Bridge.islandTab === "wallpaper" ? wallpaperTab
                        : Bridge.islandTab === "theme" ? themeTab
                        : Bridge.islandTab === "island" ? islandTab
                        : Bridge.islandTab === "power" ? powerTab
                        : volumeTab
                }
            }

            ScrollIndicator { target: flick }
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
    Component { id: screenshotTab; ScreenshotTab {} }
    Component { id: weatherTab; WeatherPanel {} }
    Component { id: activityTab; ActivityTab {} }
    Component { id: notificationsTab; NotificationHistoryTab {} }
    Component { id: nightlightTab; NightLightTab {} }
    Component { id: displayTab; DisplayTab {} }
    Component { id: idleTab; IdleTab {} }
    Component { id: wallpaperTab; WallpaperSettings {} }
    Component { id: themeTab; ThemeSettings {} }
    Component { id: islandTab; IslandSettings {} }
    Component { id: powerTab; PowerTab {} }
}
