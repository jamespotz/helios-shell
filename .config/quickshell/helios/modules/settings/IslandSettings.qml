import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Settings > Island — what the idle bump and expanded island show, their
// sizing, and how the island and its satellites move. Everything applies
// as you change it; each section has its own Reset.
SettingsPreviewPage {
    id: root
    title: "Island"
    icon: "auto_awesome"
    previewComponent: Component { IslandPreview {} }

    readonly property var widgetMeta: ({
        focusTimer: { icon: "timer", label: qsTr("Focus timer") },
        launcher: { icon: "apps", label: "Launcher" },
        media: { icon: "music_note", label: "Now-playing cover" },
        clock: { icon: "schedule", label: "Clock" },
        weather: { icon: "cloud", label: "Weather" },
        tiledLayout: { icon: "dashboard", label: "Tiled layout" },
        workspaces: { icon: "grid_view", label: "Workspaces" },
        activeWindow: { icon: "web_asset", label: "Active window" },
        tray: { icon: "widgets", label: "Tray icons" },
        statusIndicators: { icon: "sensors", label: "Status icons" },
        clipboard: { icon: "content_paste", label: "Clipboard" }
    })
    readonly property var idleWidgetKeys: Config.widgetKeys.idle.map(k => Config.widgetOption("idle", k)).concat(["idleLayout"])
    readonly property var peekWidgetKeys: Config.widgetKeys.peek.map(k => Config.widgetOption("peek", k)).concat(["peekLayout"])

    component ConfigToggle: OptionToggle { target: Config }
    component ConfigSlider: OptionSlider { target: Config }
    component ConfigChoice: OptionChoice { target: Config }

    readonly property var motionChoices: [
        { value: "snappy", label: "Snappy" },
        { value: "smooth", label: "Smooth" },
        { value: "bouncy", label: "Bouncy" }
    ]

    // Raw spring sliders behind a disclosure; the Motion presets cover the
    // common cases. Summary names the active preset ("Custom" otherwise).
    component MotionAdvanced: Disclosure {
        id: advanced
        property string stiffnessKey
        property string dampingKey
        title: "Advanced motion"
        summary: Config.motionPreset.charAt(0).toUpperCase() + Config.motionPreset.slice(1)

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Higher stiffness snaps open faster. Damping near 1 stays smooth; lower overshoots, higher eases in slower."
            font.pixelSize: Config.fontSize - 2
            opacity: 0.6
        }

        SettingsCard {
            ConfigSlider { option: advanced.stiffnessKey; icon: "speed"; label: "Stiffness"; format: v => v.toFixed(1) }
            ConfigSlider { option: advanced.dampingKey; icon: "waves"; label: "Damping"; format: v => v.toFixed(1); last: true }
        }
    }

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

        Column {
            width: parent.width
            spacing: 10
            SectionTitle { title: qsTr("Launcher button"); subtitle: qsTr("Enable and position Launcher in the Idle or Expanded widget list below.") }
            SettingsCard {
                ConfigChoice {
                    option: "launcherIconMode"
                    icon: "image"
                    label: qsTr("Icon")
                    choices: [{ value: "os", label: qsTr("OS logo") }, { value: "custom", label: qsTr("Custom image") }]
                    last: true
                }
            }
            PrimaryButton {
                width: parent.width
                visible: Config.launcherIconMode === "custom"
                icon: "folder_open"
                text: qsTr("Choose icon image")
                enabled: !LauncherIcon.picking
                onClicked: LauncherIcon.chooseImage()
            }
            StyledText {
                width: parent.width
                visible: Config.launcherIconMode === "custom"
                text: Config.launcherIconPath || qsTr("No image selected. Using the OS logo.")
                elide: Text.ElideMiddle
                color: Colors.subtext
                font.pixelSize: Config.fontSize - 2
            }
            ResetChip { keys: ["launcherIconMode", "launcherIconPath"] }
        }

        // --- Idle ----------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Idle"
                subtitle: "The small collapsed pill. Drag to reorder, or drag Right side to move widgets between sides. With widgets on both sides, each hugs its edge and the middle opens up. Width and height are its resting size."
            }

            WidgetLayoutList { surface: "idle"; meta: root.widgetMeta }

            SettingsCard {
                ConfigSlider { option: "idleBumpWidth"; icon: "width"; label: "Width" }
                ConfigSlider { option: "idleBumpHeight"; icon: "height"; label: "Height" }
                ConfigSlider { option: "islandIdleCornerRadius"; icon: "rounded_corner"; label: "Corner radius"; format: v => Math.round(v) + " px" }
                ConfigSlider { option: "islandTopGap"; icon: "vertical_align_top"; label: "Top gap" }
                ConfigSlider { option: "idleWidgetSpacing"; icon: "space_bar"; label: "Widget spacing"; last: true }
            }

            ResetChip {
                keys: root.idleWidgetKeys.concat(["idleBumpWidth", "idleBumpHeight", "islandIdleCornerRadius", "islandTopGap", "idleWidgetSpacing"])
            }
        }

        // --- Expanded ------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Expanded"
                subtitle: "The hover row. Drag to reorder; a thin line separates the left and right groups."
            }

            WidgetLayoutList { surface: "peek"; meta: root.widgetMeta }

            SettingsCard {
                ConfigSlider { option: "islandContentPadH"; icon: "padding"; label: "Side padding" }
                ConfigSlider { option: "islandContentPadV"; icon: "padding"; label: "Vertical padding" }
                ConfigSlider { option: "islandExpandedCornerRadius"; icon: "rounded_corner"; label: "Corner radius"; format: v => Math.round(v) + " px" }
                ConfigSlider { option: "peekHeight"; icon: "height"; label: "Hover row height" }
                ConfigSlider { option: "islandMaxWidth"; icon: "width"; label: "Max width"; format: v => Math.round(v) + " px"; last: true }
            }

            ResetChip {
                keys: root.peekWidgetKeys.concat(["islandContentPadH", "islandContentPadV", "islandExpandedCornerRadius", "peekHeight", "islandMaxWidth"])
            }
        }

        // --- Behavior (main island: idle + expanded) ------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Behavior"
                subtitle: "With Open on hover off, click the idle pill to open it. Motion sets how the island, its satellites and the rest of the shell spring. Over fullscreen: Alerts shows alert cards and shortcut-opened panels above fullscreen apps."
            }

            SettingsCard {
                ConfigToggle { option: "hoverExpand"; icon: "arrow_selector_tool"; label: "Open on hover" }
                ConfigSlider {
                    visible: Config.hoverExpand
                    option: "hoverExpandDelay"
                    icon: "hourglass_top"
                    label: "Hover delay"
                    format: v => Math.round(v) + " ms"
                }
                ConfigSlider { option: "hoverCollapseDelay"; icon: "timer"; label: "Collapse delay"; format: v => Math.round(v) + " ms" }
                SettingsRow {
                    icon: "animation"
                    label: "Motion"
                    SegmentedControl {
                        implicitHeight: 32
                        enabled: !Config.reducedMotion
                        opacity: enabled ? 1 : 0.4
                        model: root.motionChoices
                        currentValue: Config.motionPreset
                        onActivated: v => Config.applyMotionPreset(v)
                    }
                }
                ConfigToggle { option: "reducedMotion"; icon: "motion_photos_off"; label: "Reduce motion" }
                ConfigChoice {
                    option: "islandOverFullscreen"
                    icon: "fullscreen"
                    label: "Over fullscreen"
                    choices: [{ value: "hidden", label: "Hidden" }, { value: "alerts", label: "Alerts" }]
                    last: true
                }
            }

            MotionAdvanced {
                stiffnessKey: "islandSpringStiffness"
                dampingKey: "islandSpringDamping"
            }

            ResetChip {
                keys: ["hoverExpand", "hoverExpandDelay", "hoverCollapseDelay", "islandSpringStiffness", "islandSpringDamping",
                    "islandOverFullscreen"]
            }
        }

        // --- Appearance (island and satellites) ----------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Appearance"
                subtitle: "Applies to the island and its satellites. Satellites have their own border toggle below."
            }

            SettingsCard {
                ConfigChoice {
                    option: "islandGlass"
                    icon: "blur_on"
                    label: "Liquid glass"
                    choices: [{ value: "follow", label: "Shell" }, { value: "on", label: "On" }, { value: "off", label: "Off" }]
                }
                ConfigSlider { option: "islandBackgroundOpacity"; icon: "opacity"; label: "Background"; format: v => Math.round(v * 100) + "%" }
                ConfigSlider { option: "islandShadowGlowRadius"; icon: "blur_circular"; label: "Shadow glow"; format: v => v.toFixed(1) + " px" }
                ConfigSlider { option: "islandShadowSpread"; icon: "gradient"; label: "Shadow spread"; format: v => v.toFixed(2) }
                ConfigToggle { option: "islandBorder"; icon: "border_style"; label: "Border" }
                ConfigSlider {
                    visible: Config.islandBorder
                    option: "islandBorderWidth"
                    icon: "line_weight"
                    label: "Border width"
                    format: v => v.toFixed(1) + " px"
                }
                ConfigChoice {
                    visible: Config.islandBorder || Config.satelliteBorder
                    option: "islandBorderColor"
                    icon: "palette"
                    label: "Border color"
                    choices: [{ value: "outline", label: "Outline" }, { value: "accent", label: "Accent" }]
                }
                ConfigSlider {
                    visible: Config.islandBorder || Config.satelliteBorder
                    option: "islandBorderOpacity"
                    icon: "opacity"
                    label: "Border opacity"
                    format: v => Math.round(v * 100) + "%"
                    last: true
                }
            }

            ResetChip {
                keys: ["islandGlass", "islandBackgroundOpacity", "islandShadowGlowRadius", "islandShadowSpread",
                    "islandBorder", "islandBorderWidth", "islandBorderColor", "islandBorderOpacity"]
            }
        }

        // --- Gestures ------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Gestures"
                subtitle: "On the idle pill and hover row. Open panels and alerts keep their own clicks."
            }

            SettingsCard {
                ConfigChoice {
                    option: "gestureScroll"
                    icon: "swap_vert"
                    label: "Scroll"
                    choices: [{ value: "off", label: "Off" }, { value: "volume", label: "Volume" }, { value: "workspace", label: "Workspace" }]
                }
                ConfigChoice {
                    option: "gestureMiddleClick"
                    icon: "mouse"
                    label: "Middle click"
                    choices: [{ value: "off", label: "Off" }, { value: "playpause", label: "Play/pause" }, { value: "mute", label: "Mute" }]
                    last: true
                }
            }

            StyledText {
                text: "Right click opens"
                font.pixelSize: Config.fontSize - 1
                opacity: 0.8
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: Config.options.gestureRightClick.choices

                    Chip {
                        required property string modelData
                        readonly property var destination: IslandNavigation.resolve(modelData)
                        active: Config.gestureRightClick === modelData
                        text: destination ? destination.label : "Nothing"
                        onClicked: Config.setOption("gestureRightClick", modelData)
                    }
                }
            }

            ResetChip { keys: ["gestureScroll", "gestureMiddleClick", "gestureRightClick"] }
        }

        // --- Alerts --------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Alerts"
                subtitle: "Cards that take over the island. Hovering a notification keeps it open; low-priority ones leave in half the time."
            }

            SettingsCard {
                SettingsRow {
                    icon: "do_not_disturb_on"
                    label: "Do Not Disturb"
                    Toggle {
                        label: "Do Not Disturb"
                        checked: ShellState.dndEnabled
                        onToggled: v => ShellState.setDndEnabled(v)
                    }
                }
                ConfigToggle { option: "showTaskAlerts"; icon: "progress_activity"; label: "Task progress" }
                ConfigToggle { option: "showMeetingAlerts"; icon: "event"; label: "Meeting reminders" }
                ConfigToggle { option: "showBatteryAlerts"; icon: "battery_alert"; label: "Device battery" }
                ConfigSlider {
                    visible: Config.showBatteryAlerts
                    option: "batteryAlertThreshold"
                    icon: "battery_2_bar"
                    label: "Battery below"
                    format: v => Math.round(v) + "%"
                }
                ConfigToggle { option: "keepCriticalAlerts"; icon: "priority_high"; label: "Keep critical until dismissed" }
                ConfigToggle { option: "alertSounds"; icon: "volume_up"; label: "Alert sounds"; last: true }
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

            ResetChip {
                keys: ["showTaskAlerts", "showMeetingAlerts", "showBatteryAlerts", "batteryAlertThreshold",
                    "keepCriticalAlerts", "alertSounds", "notifyWidth", "notifyDuration"]
            }
        }

        // --- Satellite -----------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Satellite"
                subtitle: "The small badges next to the island (recording, maintenance). Motion presets set their spring too; Advanced tunes it separately."
            }

            SettingsCard {
                ConfigSlider { option: "satelliteBadgeSize"; icon: "circle"; label: "Badge size" }
                ConfigSlider { option: "satelliteRestGap"; icon: "space_bar"; label: "Gap" }
                ConfigSlider { option: "satellitePadH"; icon: "padding"; label: "Side padding" }
                ConfigSlider { option: "satellitePadV"; icon: "padding"; label: "Vertical padding" }
                ConfigSlider { option: "satelliteShadowGlowRadius"; icon: "blur_circular"; label: "Shadow glow"; format: v => v.toFixed(1) + " px" }
                ConfigSlider { option: "satelliteShadowSpread"; icon: "gradient"; label: "Shadow spread"; format: v => v.toFixed(2) }
                ConfigToggle { option: "satelliteBorder"; icon: "border_style"; label: "Border"; last: !Config.satelliteBorder }
                ConfigSlider {
                    visible: Config.satelliteBorder
                    option: "satelliteBorderWidth"
                    icon: "line_weight"
                    label: "Border width"
                    format: v => v.toFixed(1) + " px"
                    last: true
                }
            }

            MotionAdvanced {
                stiffnessKey: "satelliteSpringStiffness"
                dampingKey: "satelliteSpringDamping"
            }

            ResetChip {
                keys: ["satelliteBadgeSize", "satelliteRestGap", "satellitePadH", "satellitePadV",
                    "satelliteShadowGlowRadius", "satelliteShadowSpread", "satelliteSpringStiffness", "satelliteSpringDamping",
                    "satelliteBorder", "satelliteBorderWidth"]
            }
        }

        // --- Launcher ------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Launcher"
                subtitle: "Destinations offered in Launcher search. Shortcuts and status icons still open hidden ones."
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: IslandNavigation.destinations.filter(d => d.id !== "launcher")

                    Chip {
                        required property var modelData
                        active: !Config.destinationHidden(modelData.id)
                        text: modelData.id === "powermenu" ? "Power menu" : modelData.label
                        onClicked: Config.setDestinationHidden(modelData.id, active)
                    }
                }
            }

            ResetChip { keys: ["hiddenDestinations"] }
        }

        // --- Screens -------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Screens"
                subtitle: "Panels opened with a shortcut still appear on a screen that's off. At least one screen keeps the island. If the alert screen is missing or off, alerts show everywhere."
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

            StyledText {
                text: "Show alerts on"
                font.pixelSize: Config.fontSize - 1
                opacity: 0.8
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [{ value: "all", label: "All screens" }, { value: "focused", label: "Focused screen" }]
                        .concat(Quickshell.screens.filter(s => s.name).map(s => ({ value: s.name, label: s.name })))

                    Chip {
                        required property var modelData
                        active: Config.alertScreen === modelData.value
                        text: modelData.label
                        onClicked: Config.setOption("alertScreen", modelData.value)
                    }
                }
            }

            ResetChip { keys: ["alertScreen"] }
        }

        // --- Presets -------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            SectionTitle {
                title: "Presets"
                subtitle: "Copy every Island setting to the clipboard as text, or paste one back. Screen choices stay per machine."
            }

            Row {
                spacing: 8
                Chip { text: "Copy settings"; inactiveTint: Colors.surfaceHigh; onClicked: Config.copyIslandPreset() }
                Chip { text: "Paste settings"; inactiveTint: Colors.surfaceHigh; onClicked: Config.pasteIslandPreset() }
                Chip { text: "Reset all"; inactiveTint: Colors.surfaceHigh; onClicked: Config.resetOptions(Config.islandKeys) }
            }

            StyledText {
                visible: Config.presetStatus !== ""
                text: Config.presetStatus
                font.pixelSize: Config.fontSize - 1
                color: Colors.subtext
            }
        }
    }
}
