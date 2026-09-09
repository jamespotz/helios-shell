import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

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

    visible: Bridge.settingsOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:settings"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    mask: Region { item: card }

    readonly property var pages: [
        { id: "appearance", label: "Appearance", icon: "palette", group: "Personalization",
          keywords: ["theme", "dark mode", "color", "palette", "scheme", "wallpaper colors"] },
        { id: "wallpaper", label: "Wallpaper", icon: "wallpaper", group: "Personalization",
          keywords: ["wallpaper", "background", "transition", "folder"] },
        { id: "helios", label: "Helios", icon: "auto_awesome", group: "Personalization",
          keywords: ["island", "idle bump", "widgets", "clock format", "weather location", "liquid glass", "spring", "morph", "collapse delay"] },
        { id: "displays", label: "Displays", icon: "monitor", group: "Hardware",
          keywords: ["resolution", "refresh rate", "scale", "vrr", "adaptive sync", "night light", "blue light", "warmth", "color temperature"] },
        { id: "sound", label: "Sound", icon: "volume_up", group: "Hardware",
          keywords: ["volume", "mixer", "output", "input", "audio", "device"] },
        { id: "bluetooth", label: "Bluetooth", icon: "bluetooth", group: "Hardware",
          keywords: ["pair", "device", "audio profile", "discoverable"] },
        { id: "wifi", label: "Wi-Fi", icon: "wifi", group: "Connectivity",
          keywords: ["network", "wireless", "connect", "password"] },
        { id: "notifications", label: "Notifications", icon: "notifications", group: "Attention",
          keywords: ["history", "do not disturb", "dnd", "alerts"] },
        { id: "focus", label: "Focus", icon: "do_not_disturb_on", group: "Attention",
          keywords: ["focus mode", "silence", "automation"] },
        { id: "privacy", label: "Privacy", icon: "privacy_tip", group: "Attention",
          keywords: ["microphone", "camera", "indicator", "clipboard"] },
        { id: "lockscreen", label: "Lock screen", icon: "bedtime", group: "System",
          keywords: ["auto-lock", "caffeine mode", "dim screen", "turn off display", "idle"] },
        { id: "power", label: "Power", icon: "bolt", group: "System",
          keywords: ["power profile", "battery", "performance", "balanced", "power saver"] },
        { id: "keyboard", label: "Keyboard", icon: "keyboard", group: "System",
          keywords: ["shortcuts", "keybinds", "cheatsheet"] },
        { id: "systemmonitor", label: "System monitor", icon: "memory", group: "System",
          keywords: ["cpu", "gpu", "ram", "memory", "processes", "disk", "network usage"] },
        { id: "automation", label: "Automation", icon: "settings_suggest", group: "System",
          keywords: ["device rules", "headphones", "trigger", "action", "connect"] }
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

    Rectangle {
        id: card
        anchors.centerIn: parent
        // Content is a fixed 560px, positioned 21px right of the sidebar —
        // the remainder past that (past sidebar 220 + 1px divider) is the
        // page's own right-side breathing room. Reused tabs (BluetoothTab,
        // WifiTab, etc.) size their Column to fill exactly the width the
        // Loader gives them and anchor controls to its right edge — in the
        // island that edge IS the panel's edge (the panel always shrinks to
        // the tab's own implicitWidth), but here the card is wider than the
        // content column, so this margin is what keeps those controls off
        // the card's true edge instead of touching it.
        width: 828
        height: 600
        radius: Colors.radiusLarge
        color: Colors.surface
        opacity: Colors.panelOpacity
        border.width: 0.5
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)
        clip: true

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
                sourceComponent: settingsWindow.selectedPage === "wallpaper" ? wallpaperPage
                    : settingsWindow.selectedPage === "displays" ? displaysPage
                    : settingsWindow.selectedPage === "sound" ? soundPage
                    : settingsWindow.selectedPage === "bluetooth" ? bluetoothPage
                    : settingsWindow.selectedPage === "wifi" ? wifiPage
                    : settingsWindow.selectedPage === "notifications" ? notificationsPage
                    : settingsWindow.selectedPage === "focus" ? focusPage
                    : settingsWindow.selectedPage === "privacy" ? privacyPage
                    : settingsWindow.selectedPage === "lockscreen" ? lockscreenPage
                    : settingsWindow.selectedPage === "power" ? powerPage
                    : settingsWindow.selectedPage === "keyboard" ? keyboardPage
                    : settingsWindow.selectedPage === "systemmonitor" ? systemMonitorPage
                    : settingsWindow.selectedPage === "automation" ? automationPage
                    : settingsWindow.selectedPage === "helios" ? heliosPage
                    : appearancePage

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

    Component { id: appearancePage; ThemeSettings {} }
    Component { id: wallpaperPage; WallpaperSettings {} }
    // Night Light stacked below the monitor list — same physical-hardware
    // grouping as Sound (VolumeTab + AudioMixerTab) below.
    Component {
        id: displaysPage
        Item {
            implicitWidth: displaysCol.width
            implicitHeight: displaysCol.implicitHeight

            Column {
                id: displaysCol
                width: parent.width
                spacing: 24

                DisplayTab { width: parent.width }
                NightLightTab { width: parent.width }
            }
        }
    }
    // Volume/device controls (VolumeTab, otherwise only reachable from the
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

                VolumeTab { width: parent.width }
                AudioMixerTab { width: parent.width }
            }
        }
    }
    Component { id: bluetoothPage; BluetoothTab {} }
    Component { id: wifiPage; WifiTab {} }
    Component { id: notificationsPage; NotificationHistoryTab {} }
    Component { id: focusPage; FocusTab {} }
    Component { id: privacyPage; PrivacyTab {} }
    Component { id: lockscreenPage; IdleTab {} }
    Component { id: powerPage; PowerTab {} }
    Component { id: keyboardPage; KeybindsTab {} }
    Component { id: systemMonitorPage; SystemMonitorTab {} }
    Component { id: automationPage; AutomationTab {} }
    Component { id: heliosPage; IslandSettings {} }
}
