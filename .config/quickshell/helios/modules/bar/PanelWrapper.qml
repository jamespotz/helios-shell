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

    // A tab's implicitHeight has to stay bound to its TRUE full content
    // height (see e.g. IslandSettings.qml's `implicitHeight: col.implicitHeight`)
    // because that same number also drives the Flickable's contentHeight
    // below — shrink it and the tab doesn't get shorter, it just loses the
    // ability to scroll to whatever content that number no longer accounts
    // for. To make a specific tab render shorter (and scrollable) without
    // touching its real content height, cap its effective viewport height
    // here instead, per tab.
    readonly property var _tabMaxHeight: ({ "island": 360 })
    readonly property int _effectiveMaxHeight: root._tabMaxHeight[Bridge.islandTab] || root.maxContentHeight

    implicitWidth: pane.width
    implicitHeight: tabs.height + pane.spacing + Math.min(panelLoader.implicitHeight, root._effectiveMaxHeight)

    Column {
        id: pane
        // Sized to the active tab's own content — not the tab bar, which
        // scrolls horizontally instead of forcing every tab to be at least
        // as wide as all 17 icons combined (~590px). The floor here is a
        // defensive minimum, well below any real tab's implicitWidth.
        width: Math.max(220, panelLoader.implicitWidth)
        spacing: 14

        // ─── Tab bar: segmented control style ────────────────────────────
        Item {
            id: tabs
            width: pane.width
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

            // Tab icons scroll horizontally instead of forcing the panel to
            // stay as wide as all 17 of them — no visible scrollbar, just
            // drag/flick, to keep the segmented-pill look intact.
            Flickable {
                id: tabScroll
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.right: closeButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: tabRow.implicitHeight
                contentWidth: tabRow.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: tabRow
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
            height: Math.min(panelLoader.implicitHeight, root._effectiveMaxHeight)

            Flickable {
                id: flick
                anchors.fill: parent
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
