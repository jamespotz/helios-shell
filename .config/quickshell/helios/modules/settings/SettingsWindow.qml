import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"
import "../bar"

// Dedicated settings app — separate from the Dynamic Island, which stays
// reserved for quick controls (volume, wifi, bluetooth, power profile,
// media, focus). A sidebar of pages beats the old one-tab-per-shortcut
// approach once there's more than a handful of things to configure.
//
// Same "full-screen transparent surface, mask limited to the real card"
// trick TrayMenu.qml uses to get click-outside-to-close via
// HyprlandFocusGrab while everything outside the card stays click-through.
PanelWindow {
    id: settingsWindow

    visible: Bridge.settingsOpen && !Bridge.avatarPickerOpen && !Bridge.launcherIconPickerOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:settings"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    mask: Region { item: card }

    // Sidebar entries, in order. `component` is what the content Loader
    // shows for the page; adding a page is one entry here.
    readonly property var pages: [
        { id: "appearance", label: "Appearance", icon: "palette", group: "Personalization", component: appearancePage,
          keywords: ["theme", "dark mode", "color", "palette", "scheme", "wallpaper colors", "font", "typeface", "text size", "reduce motion"] },
        { id: "wallpaper", label: "Wallpaper", icon: "wallpaper", group: "Personalization", component: wallpaperPage,
          keywords: ["wallpaper", "background", "transition", "folder"] },
        { id: "island", label: "Island", icon: "auto_awesome", group: "Personalization", component: islandPage,
          keywords: ["island", "idle bump", "widgets", "order", "reorder", "left", "right", "launcher", "destinations", "hide", "expanded", "padding", "liquid glass", "spring", "motion", "preset", "snappy", "bouncy", "reduce motion", "morph", "collapse delay", "shadow", "satellite", "badge", "gestures", "scroll", "middle click", "right click", "fullscreen", "alerts", "do not disturb", "dnd", "sounds", "critical", "battery", "meeting", "task"] },
        { id: "workspaces", label: "Workspaces", icon: "grid_view", group: "Personalization", component: workspacesPage,
          keywords: ["workspace indicator", "workspace icons", "dots", "numbers"] },
        { id: "dock", label: "Dock", icon: "dock_to_bottom", group: "Personalization", component: dockPage,
          keywords: ["dock", "taskbar", "pinned apps", "autohide", "magnification", "icon size", "window previews", "badges", "recent apps", "scroll", "liquid glass", "trash", "separator"] },
        { id: "displays", label: "Displays", icon: "monitor", group: "Hardware", component: displaysPage,
          keywords: ["resolution", "refresh rate", "scale", "vrr", "adaptive sync", "night light", "blue light", "warmth", "color temperature"] },
        { id: "sound", label: "Sound", icon: "volume_up", group: "Hardware", component: soundPage,
          keywords: ["volume", "mixer", "output", "input", "audio", "device"] },
        { id: "bluetooth", label: "Bluetooth", icon: "bluetooth", group: "Hardware", component: bluetoothPage,
          keywords: ["pair", "device", "audio profile", "discoverable"] },
        { id: "wifi", label: "Wi-Fi", icon: "wifi", group: "Connectivity", component: wifiPage,
          keywords: ["network", "wireless", "connect", "password"] },
        { id: "notifications", label: "Notifications", icon: "notifications", group: "Attention", component: notificationsPage,
          keywords: ["history", "do not disturb", "dnd", "alerts"] },
        { id: "focus", label: "Focus", icon: "do_not_disturb_on", group: "Attention", component: focusPage,
          keywords: ["focus mode", "silence", "automation"] },
        { id: "privacy", label: "Privacy", icon: "privacy_tip", group: "Attention", component: privacyPage,
          keywords: ["microphone", "camera", "indicator", "clipboard"] },
        { id: "datetime", label: "Date & time", icon: "schedule", group: "System", component: dateTimePage,
          keywords: ["clock", "clock format", "24-hour", "am/pm", "time"] },
        { id: "weather", label: "Weather", icon: "partly_cloudy_day", group: "System", component: weatherPage,
          keywords: ["weather location", "city", "latitude", "longitude", "forecast"] },
        { id: "lockscreen", label: "Lock screen", icon: "bedtime", group: "System", component: lockscreenPage,
          keywords: ["auto-lock", "caffeine mode", "dim screen", "turn off display", "idle"] },
        { id: "power", label: "Power", icon: "bolt", group: "System", component: powerPage,
          keywords: ["power profile", "battery", "performance", "balanced", "power saver"] },
        { id: "keyboard", label: "Keyboard", icon: "keyboard", group: "System", component: keyboardPage,
          keywords: ["shortcuts", "keybinds", "cheatsheet"] },
        { id: "systemmonitor", label: "System monitor", icon: "memory", group: "System", component: systemMonitorPage,
          keywords: ["cpu", "gpu", "ram", "memory", "processes", "disk", "network usage"] },
        { id: "automation", label: "Automation", icon: "settings_suggest", group: "System", component: automationPage,
          keywords: ["device rules", "headphones", "trigger", "action", "connect"] },
        { id: "defaultapps", label: "Default Apps", icon: "apps", group: "System", component: defaultAppsPage,
          keywords: ["browser", "file manager", "text editor", "xdg-mime", "association"] }
    ]

    property string searchText: ""

    function pageMatches(page, query) {
        if (!query) return true;
        const q = query.toLowerCase();
        if (page.label.toLowerCase().includes(q)) return true;
        return page.keywords.some(k => k.toLowerCase().includes(q));
    }

    readonly property var filteredPages: pages.filter(p => settingsWindow.pageMatches(p, settingsWindow.searchText))

    readonly property var groupOrder: ["Personalization", "Hardware", "Connectivity", "Attention", "System"]

    readonly property var groupedPages: {
        const groups = {};
        for (const p of settingsWindow.filteredPages) {
            if (!groups[p.group]) groups[p.group] = [];
            groups[p.group].push(p);
        }
        return settingsWindow.groupOrder.filter(g => groups[g]).map(g => ({ name: g, items: groups[g] }));
    }

    readonly property string selectedPage: settingsWindow.filteredPages.some(p => p.id === Bridge.settingsPage)
        ? Bridge.settingsPage
        : (settingsWindow.filteredPages.length > 0 ? settingsWindow.filteredPages[0].id : "")

    function selectPage(id) { Bridge.settingsPage = id }

    onVisibleChanged: if (visible) { searchField.text = ""; searchText = ""; searchField.focusInput(); }

    HyprlandFocusGrab {
        id: settingsFocusGrab
        windows: [settingsWindow]
        active: settingsWindow.visible
        onCleared: Bridge.closeSettings()
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: settingsWindow.visible
        onActivated: searchField.focusInput()
    }

    // Fallback Escape catch — SearchField's own TextInput already forwards
    // Escape via escapePressed below; this covers focus sitting anywhere
    // else in the card (a sidebar row, a control inside the active page).
    Item {
        anchors.fill: parent
        focus: settingsWindow.visible
        Keys.onEscapePressed: Bridge.closeSettings()
    }

    SurfaceShadow {
        anchors.fill: card
        cornerRadius: card.radius
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        // Content is a fixed 560px, positioned 21px right of the sidebar —
        // the remainder past that (past sidebar 220 + 1px divider) is the
        // page's own right-side breathing room. Reused tabs (BluetoothIsland,
        // WifiIsland, etc.) size their Column to fill exactly the width the
        // Loader gives them and anchor controls to its right edge — in the
        // island that edge IS the panel's edge (the panel always shrinks to
        // the tab's own implicitWidth), but here the card is wider than the
        // content column, so this margin is what keeps those controls off
        // the card's true edge instead of touching it.
        width: 828
        height: 600
        radius: Colors.radiusLarge
        // Opaque by default (LiquidGlassSurface's fallback paints fillColor
        // at full alpha) and only picks up the translucent vibrancy look
        // when the same toggle the island uses is on.
        color: "transparent"
        border.width: 0.5
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)
        clip: true

        LiquidGlassSurface {
            anchors.fill: parent
            active: Bridge.liquidGlassEnabled
            cornerRadius: card.radius
            fallbackColor: Colors.surface
        }

        // ─── Header: search + close ──────────────────────────────────────
        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            height: 40

            SearchField {
                id: searchField
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - 10
                height: 40
                placeholder: "Search settings"
                onTextChanged: settingsWindow.searchText = text
                onEscapePressed: Bridge.closeSettings()
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                onClicked: Bridge.closeSettings()
            }
        }

        Rectangle {
            id: headerDivider
            anchors.top: header.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Colors.overlay
            opacity: 0.15
        }

        // ─── Sidebar ──────────────────────────────────────────────────────
        Flickable {
            id: sidebar
            anchors.top: headerDivider.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: 220
            contentWidth: width
            contentHeight: sidebarCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: sidebarCol
                width: sidebar.width - 20
                x: 10
                spacing: 14

                Row {
                    width: sidebarCol.width
                    height: 44
                    spacing: 10
                    leftPadding: 6
                    bottomPadding: 6

                    Avatar {
                        size: 32
                        editable: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: Quickshell.env("USER") || "User"
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: settingsWindow.groupedPages

                    Column {
                        id: groupDelegate
                        required property var modelData
                        width: sidebarCol.width
                        spacing: 2

                        StyledText {
                            text: groupDelegate.modelData.name
                            font.pixelSize: Config.fontSize - 2
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            color: Colors.subtext
                            leftPadding: 10
                            bottomPadding: 4
                        }

                        Repeater {
                            model: groupDelegate.modelData.items

                            HoverRow {
                                id: pageRow
                                required property var modelData
                                width: sidebarCol.width
                                height: 44
                                highlighted: settingsWindow.selectedPage === pageRow.modelData.id
                                onClicked: settingsWindow.selectPage(pageRow.modelData.id)

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10

                                    MaterialIcon {
                                        icon: pageRow.modelData.icon
                                        font.pixelSize: 16
                                        color: pageRow.highlighted ? Colors.accent : Colors.text
                                        opacity: pageRow.highlighted ? 1 : 0.8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    StyledText {
                                        text: pageRow.modelData.label
                                        color: pageRow.highlighted ? Colors.accent : Colors.text
                                        font.weight: pageRow.highlighted ? Font.Medium : Font.Normal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    visible: settingsWindow.filteredPages.length === 0
                    width: sidebarCol.width
                    leftPadding: 10
                    wrapMode: Text.WordWrap
                    color: Colors.subtext
                    text: "No settings match \"" + settingsWindow.searchText + "\""
                }
            }
        }

        Rectangle {
            anchors.top: headerDivider.bottom
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            width: 1
            color: Colors.overlay
            opacity: 0.15
        }

        // ─── Content ──────────────────────────────────────────────────────
        Flickable {
            id: contentFlick
            anchors.top: headerDivider.bottom
            anchors.topMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.left: sidebar.right
            anchors.leftMargin: 21
            width: 560
            contentWidth: width
            contentHeight: pageLoader.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Loader {
                id: pageLoader
                width: contentFlick.width
                // Unloads on close instead of just hiding — a PanelWindow's
                // tree survives `visible: false`, so without this any
                // unapplied draft edit (font family, island width, satellite
                // spring...) would still be sitting there next time the
                // window opens instead of resyncing to the real Config value.
                active: settingsWindow.visible
                sourceComponent: (settingsWindow.pages.find(p => p.id === settingsWindow.selectedPage) || settingsWindow.pages[0]).component

                opacity: 0
                Behavior on opacity {
                    enabled: !Config.reducedMotion
                    NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
                }
                onSourceComponentChanged: opacity = 0
                onLoaded: opacity = 1
            }
        }

        ScrollIndicator { target: sidebar }
        ScrollIndicator { target: contentFlick }
    }

    // Fonts stacked below the theme — both are how the shell looks.
    Component {
        id: appearancePage
        Item {
            implicitWidth: appearanceCol.width
            implicitHeight: appearanceCol.implicitHeight

            Column {
                id: appearanceCol
                width: parent.width
                spacing: 24

                ThemeSettings { width: parent.width }
                FontSettings { width: parent.width }
            }
        }
    }
    Component { id: wallpaperPage; WallpaperSettings {} }
    // Night Light stacked below the monitor list — same physical-hardware
    // grouping as Sound (VolumeIsland + AudioMixerIsland) below.
    Component {
        id: displaysPage
        Item {
            implicitWidth: displaysCol.width
            implicitHeight: displaysCol.implicitHeight

            Column {
                id: displaysCol
                width: parent.width
                spacing: 24

                DisplayIsland { width: parent.width }
                NightLightIsland { width: parent.width }
            }
        }
    }
    // Volume/device controls (VolumeIsland, otherwise only reachable from the
    // island) stacked above the per-app mixer, so Sound covers both without
    // a separate page.
    Component {
        id: soundPage
        Item {
            implicitWidth: soundCol.width
            implicitHeight: soundCol.implicitHeight

            Column {
                id: soundCol
                width: parent.width
                spacing: 24

                VolumeIsland { width: parent.width }
                AudioMixerIsland { width: parent.width }
            }
        }
    }
    Component { id: bluetoothPage; BluetoothIsland {} }
    Component { id: wifiPage; WifiIsland {} }
    Component { id: notificationsPage; NotificationHistoryIsland {} }
    Component { id: focusPage; FocusIsland {} }
    Component { id: privacyPage; PrivacyIsland {} }
    Component { id: lockscreenPage; IdleIsland {} }
    Component { id: powerPage; PowerIsland {} }
    Component { id: keyboardPage; KeybindsIsland {} }
    Component { id: systemMonitorPage; SystemMonitorIsland {} }
    Component { id: automationPage; AutomationIsland {} }
    Component { id: defaultAppsPage; DefaultAppsIsland {} }
    Component { id: islandPage; IslandSettings {} }
    Component { id: workspacesPage; WorkspaceSettings {} }
    Component { id: dateTimePage; DateTimeSettings {} }
    Component { id: weatherPage; WeatherSettings {} }
    Component { id: dockPage; DockSettings {} }
}
