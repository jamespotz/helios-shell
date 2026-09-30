import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Settings > Island — what the idle bump and expanded island show, their
// sizing, and how the island and its satellites move. Everything applies
// as you change it; each section has its own Reset.
Item {
    id: root

    readonly property var idleWidgetOptions: [
        { key: "showIdleMedia", icon: "music_note", label: "Now-playing cover" },
        { key: "showIdleClock", icon: "schedule", label: "Clock" },
        { key: "showIdleWeather", icon: "cloud", label: "Weather" },
        { key: "showIdleTiledLayout", icon: "dashboard", label: "Tiled layout" },
        { key: "showIdleWorkspaces", icon: "grid_view", label: "Workspaces" },
        { key: "showIdleActiveWindow", icon: "web_asset", label: "Active window" },
        { key: "showIdleTray", icon: "widgets", label: "Tray icons" },
        { key: "showIdleStatusIndicators", icon: "sensors", label: "Status icons" },
        { key: "showIdleClipboard", icon: "content_paste", label: "Clipboard" }
    ]

    readonly property var widgetOptions: [
        { key: "showWorkspaces", icon: "grid_view", label: "Workspaces" },
        { key: "showTiledLayout", icon: "dashboard", label: "Tiled layout" },
        { key: "showActiveWindow", icon: "web_asset", label: "Active window" },
        { key: "showClock", icon: "schedule", label: "Clock" },
        { key: "showWeather", icon: "cloud", label: "Weather" },
        { key: "showTray", icon: "widgets", label: "Tray icons" },
        { key: "showStatusIndicators", icon: "sensors", label: "Status icons" },
        { key: "showClipboard", icon: "content_paste", label: "Clipboard" }
    ]

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    component ConfigToggle: OptionToggle { target: Config }
    component ConfigSlider: OptionSlider { target: Config }

    // Section-level Reset, right-aligned under its card.
    component ResetChip: Chip {
        property var keys: []
        anchors.right: parent ? parent.right : undefined
        text: "Reset"
        inactiveTint: Colors.surfaceHigh
        onClicked: Config.resetOptions(keys)
    }

    Column {
        id: col
        width: parent.width
        spacing: 20

        Row {
            spacing: 8
            MaterialIcon { icon: "auto_awesome"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Island"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        // --- Idle ----------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Idle"
                subtitle: "The small collapsed pill. Width and height are its resting size — the island still grows past them when hovered or expanded."
            }

            SettingsCard {
                Repeater {
                    model: root.idleWidgetOptions
                    ConfigToggle {
                        required property var modelData
                        required property int index
                        icon: modelData.icon
                        label: modelData.label
                        option: modelData.key
                        last: index === root.idleWidgetOptions.length - 1
                    }
                }
            }

            SettingsCard {
                ConfigSlider { option: "idleBumpWidth"; icon: "width"; label: "Width" }
                ConfigSlider { option: "idleBumpHeight"; icon: "height"; label: "Height" }
                ConfigSlider { option: "islandTopGap"; icon: "vertical_align_top"; label: "Top gap" }
                ConfigSlider { option: "idleWidgetSpacing"; icon: "space_bar"; label: "Widget spacing"; last: true }
            }

            ResetChip {
                keys: root.idleWidgetOptions.map(o => o.key)
                    .concat(["idleBumpWidth", "idleBumpHeight", "islandTopGap", "idleWidgetSpacing"])
            }
        }

        // --- Expanded ------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Expanded"
                subtitle: "What shows and how much padding it gets when the island expands."
            }

            SettingsCard {
                Repeater {
                    model: root.widgetOptions
                    ConfigToggle {
                        required property var modelData
                        required property int index
                        icon: modelData.icon
                        label: modelData.label
                        option: modelData.key
                        last: index === root.widgetOptions.length - 1
                    }
                }
            }

            SettingsCard {
                ConfigSlider { option: "islandContentPadH"; icon: "padding"; label: "Side padding" }
                ConfigSlider { option: "islandContentPadV"; icon: "padding"; label: "Vertical padding" }
                ConfigSlider { option: "peekHeight"; icon: "height"; label: "Hover row height"; last: true }
            }

            ResetChip {
                keys: root.widgetOptions.map(o => o.key).concat(["islandContentPadH", "islandContentPadV", "peekHeight"])
            }
        }

        // --- Behavior (main island: idle + expanded) ------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Behavior"
                subtitle: "With Open on hover off, click the idle pill to open it. Higher stiffness snaps open faster; damping near 1 stays smooth, lower values overshoot, higher values ease in slower."
            }

            SettingsCard {
                SettingsRow {
                    icon: "blur_on"
                    label: "Liquid glass"
                    Toggle {
                        label: "Liquid glass"
                        checked: Bridge.liquidGlassEnabled
                        onToggled: v => Bridge.liquidGlassEnabled = v
                    }
                }
                ConfigToggle { option: "hoverExpand"; icon: "arrow_selector_tool"; label: "Open on hover" }
                ConfigSlider {
                    visible: Config.hoverExpand
                    option: "hoverExpandDelay"
                    icon: "hourglass_top"
                    label: "Hover delay"
                    format: v => Math.round(v) + " ms"
                }
                ConfigSlider { option: "hoverCollapseDelay"; icon: "timer"; label: "Collapse delay"; format: v => Math.round(v) + " ms" }
                ConfigSlider { option: "islandSpringStiffness"; icon: "speed"; label: "Stiffness"; format: v => v.toFixed(1) }
                ConfigSlider { option: "islandSpringDamping"; icon: "waves"; label: "Damping"; format: v => v.toFixed(1) }
                ConfigSlider { option: "islandShadowGlowRadius"; icon: "blur_circular"; label: "Shadow glow"; format: v => v.toFixed(1) + " px" }
                ConfigSlider { option: "islandShadowSpread"; icon: "gradient"; label: "Shadow spread"; format: v => v.toFixed(2); last: true }
            }

            ResetChip {
                keys: ["hoverExpand", "hoverExpandDelay", "hoverCollapseDelay", "islandSpringStiffness", "islandSpringDamping", "islandShadowGlowRadius", "islandShadowSpread"]
            }
        }

        // --- Alerts --------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Alerts"
                subtitle: "Notification, task, meeting, and battery cards. Hovering a notification keeps it open."
            }

            SettingsCard {
                ConfigSlider { option: "notifyWidth"; icon: "width"; label: "Card width" }
                ConfigSlider {
                    option: "notifyDuration"
                    icon: "timer"
                    label: "Notification time"
                    format: v => (v / 1000).toFixed(1) + " s"
                    last: true
                }
            }

            ResetChip { keys: ["notifyWidth", "notifyDuration"] }
        }

        // --- Satellite -----------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Satellite"
                subtitle: "The small badges next to the island (recording, maintenance). Their motion is independent from the island's."
            }

            SettingsCard {
                ConfigSlider { option: "satelliteBadgeSize"; icon: "circle"; label: "Badge size" }
                ConfigSlider { option: "satelliteRestGap"; icon: "space_bar"; label: "Gap" }
                ConfigSlider { option: "satellitePadH"; icon: "padding"; label: "Side padding" }
                ConfigSlider { option: "satellitePadV"; icon: "padding"; label: "Vertical padding" }
                ConfigSlider { option: "satelliteShadowGlowRadius"; icon: "blur_circular"; label: "Shadow glow"; format: v => v.toFixed(1) + " px" }
                ConfigSlider { option: "satelliteShadowSpread"; icon: "gradient"; label: "Shadow spread"; format: v => v.toFixed(2) }
                ConfigSlider { option: "satelliteSpringStiffness"; icon: "speed"; label: "Stiffness"; format: v => v.toFixed(1) }
                ConfigSlider { option: "satelliteSpringDamping"; icon: "waves"; label: "Damping"; format: v => v.toFixed(1); last: true }
            }

            ResetChip {
                keys: ["satelliteBadgeSize", "satelliteRestGap", "satellitePadH", "satellitePadV",
                    "satelliteShadowGlowRadius", "satelliteShadowSpread", "satelliteSpringStiffness", "satelliteSpringDamping"]
            }
        }

        // --- Screens -------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Screens"
                subtitle: "Panels opened with a shortcut still appear on a screen that's off. At least one screen keeps the island."
            }

            SettingsCard {
                Repeater {
                    model: Quickshell.screens

                    SettingsRow {
                        id: screenRow
                        required property var modelData
                        required property int index
                        readonly property bool shown: Config.islandShownOn(modelData.name)
                        // Never let the last shown screen be turned off —
                        // alerts would have nowhere to appear.
                        readonly property bool onlyShown: shown
                            && Quickshell.screens.filter(s => Config.islandShownOn(s.name)).length === 1
                        icon: "monitor"
                        label: modelData.name
                        last: index === Quickshell.screens.length - 1

                        Toggle {
                            label: screenRow.modelData.name
                            enabled: !screenRow.onlyShown
                            checked: screenRow.shown
                            onToggled: v => Config.setIslandShownOn(screenRow.modelData.name, v)
                        }
                    }
                }
            }
        }
    }
}
