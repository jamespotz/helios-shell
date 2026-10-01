import QtQuick
import Quickshell
import "../../services"
import "../../components"
import "../dock"

// Settings > Dock — visibility, hiding behavior, icon size, and which
// screens show the Dock.
Item {
    id: root

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    component DockToggle: OptionToggle { target: Dock }
    component DockChoice: OptionChoice { target: Dock }
    component DockSlider: OptionSlider { target: Dock }

    Column {
        id: col
        width: parent.width
        spacing: 20

        Row {
            spacing: 8
            MaterialIcon { icon: "dock_to_bottom"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Dock"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        SettingsCard {
            DockToggle { icon: "dock_to_bottom"; label: "Show Dock"; option: "enabled"; last: true }
        }

        Column {
            width: parent.width
            spacing: 10
            opacity: Dock.enabled ? 1 : 0.4
            enabled: Dock.enabled

            SectionTitle {
                title: "Behavior"
                subtitle: Dock.autohide === "intellihide" ? "Hides when a window would cover it. Move the pointer to the screen edge to reveal it."
                    : Dock.autohide === "always" ? "Stays hidden until the pointer reaches the screen edge."
                    : "Always visible. Windows are kept clear of it."
            }

            SettingsCard {
                DockChoice {
                    icon: "dock_to_bottom"
                    label: "Position"
                    option: "position"
                    choices: [
                        { value: "left", label: "Left" },
                        { value: "bottom", label: "Bottom" },
                        { value: "right", label: "Right" }
                    ]
                }
                DockChoice {
                    icon: "align_horizontal_center"
                    label: "Alignment"
                    option: "alignment"
                    choices: [
                        { value: "start", label: "Start" },
                        { value: "center", label: "Center" },
                        { value: "end", label: "End" }
                    ]
                }
                DockChoice {
                    icon: "visibility_off"
                    label: "Hide"
                    option: "autohide"
                    choices: [
                        { value: "intellihide", label: "Smart" },
                        { value: "always", label: "Always" },
                        { value: "never", label: "Never" }
                    ]
                }
                DockChoice {
                    icon: "fullscreen"
                    label: "Over fullscreen"
                    option: "overFullscreen"
                    choices: [
                        { value: "hidden", label: "Hidden" },
                        { value: "reveal", label: "On hover" }
                    ]
                }
                DockSlider {
                    visible: Dock.autohide !== "never"
                    icon: "timer"
                    label: "Hide delay"
                    option: "hideDelay"
                    format: v => Math.round(v) + " ms"
                }
                DockToggle { icon: "apps"; label: "Show running apps"; option: "showRunning" }
                DockToggle { icon: "history"; label: "Show recent apps"; option: "showRecents" }
                DockSlider {
                    visible: Dock.showRecents
                    icon: "history"
                    label: "Recent apps"
                    option: "recentCount"
                    format: v => Math.round(v)
                }
                DockChoice {
                    icon: "select_window"
                    label: "Show windows from"
                    option: "runningScope"
                    choices: [
                        { value: "all", label: "All" },
                        { value: "monitor", label: "This screen" },
                        { value: "workspace", label: "Workspace" }
                    ]
                }
                DockToggle { icon: "web_asset"; label: "Window previews"; option: "previews"; last: true }
            }

            Item { width: 1; height: 4 }

            SectionTitle {
                title: "Clicking"
                subtitle: "Minimized windows move to a hidden workspace; click the app again to bring them back."
            }

            SettingsCard {
                DockChoice {
                    icon: "left_click"
                    label: "Click focused app"
                    option: "focusedClick"
                    choices: [
                        { value: "cycle", label: "Cycle" },
                        { value: "minimize", label: "Minimize" },
                        { value: "none", label: "Nothing" }
                    ]
                }
                DockToggle { icon: "swap_vert"; label: "Scroll to cycle windows"; option: "scrollCycle" }
                DockChoice {
                    icon: "mouse"
                    label: "Middle-click"
                    option: "middleClick"
                    last: true
                    choices: [
                        { value: "new", label: "New window" },
                        { value: "close", label: "Close" }
                    ]
                }
            }

            Item { width: 1; height: 4 }

            SectionTitle { title: "Motion" }

            SettingsCard {
                DockToggle { icon: "animation"; label: "Bounce while launching"; option: "launchBounce" }
                DockToggle { icon: "label"; label: "App name on hover"; option: "showTooltips" }
                DockSlider {
                    icon: "speed"
                    label: "Show/hide speed"
                    option: "revealDuration"
                    format: v => Math.round(v) + " ms"
                    last: true
                }
            }

            Item { width: 1; height: 4 }

            SectionTitle { title: "Icons" }

            SettingsCard {
                DockToggle { icon: "fiber_manual_record"; label: "Running indicators"; option: "showIndicators" }
                DockChoice {
                    visible: Dock.showIndicators
                    icon: "more_horiz"
                    label: "Indicator style"
                    option: "indicatorStyle"
                    choices: [
                        { value: "dot", label: "Dot" },
                        { value: "line", label: "Line" },
                        { value: "windows", label: "Per window" }
                    ]
                }
                DockToggle { icon: "notifications"; label: "Notification badges"; option: "showBadges" }
                DockToggle { icon: "grid_view"; label: "All Applications button"; option: "showAppsButton" }
                DockToggle { icon: "settings"; label: "Settings button"; option: "showSettingsButton" }
                DockToggle { icon: "delete"; label: "Trash"; option: "showTrash" }
                DockToggle { icon: "zoom_in"; label: "Magnify on hover"; option: "magnify"; last: !Dock.magnify }
                DockSlider {
                    visible: Dock.magnify
                    icon: "zoom_in"
                    label: "Magnification"
                    option: "magnifyScale"
                    format: v => v.toFixed(2) + "×"
                    last: true
                }
            }

            Item { width: 1; height: 4 }

            SectionTitle { title: "Size" }

            SettingsCard {
                DockSlider { icon: "photo_size_select_large"; label: "Icon size"; option: "iconSize" }
                DockSlider { icon: "space_bar"; label: "Icon spacing"; option: "iconSpacing" }
                DockSlider { icon: "padding"; label: "Edge padding"; option: "edgePadding"; last: true }
            }

            Item { width: 1; height: 4 }

            SectionTitle { title: "Appearance" }

            SettingsCard {
                DockChoice {
                    icon: "blur_on"
                    label: "Liquid glass"
                    option: "glass"
                    choices: [
                        { value: "follow", label: "Shell" },
                        { value: "on", label: "On" },
                        { value: "off", label: "Off" }
                    ]
                }
                DockSlider { icon: "opacity"; label: "Background"; option: "backgroundOpacity"; format: v => Math.round(v * 100) + "%" }
                DockSlider { icon: "rounded_corner"; label: "Corner radius"; option: "cornerRadius" }
                DockToggle { icon: "border_style"; label: "Border"; option: "border" }
                DockSlider { visible: Dock.border; icon: "line_weight"; label: "Border width"; option: "borderWidth"; format: v => v.toFixed(1) + " px" }
                DockChoice {
                    visible: Dock.border
                    icon: "palette"
                    label: "Border color"
                    option: "borderColor"
                    choices: [
                        { value: "outline", label: "Outline" },
                        { value: "accent", label: "Accent" }
                    ]
                }
                DockSlider { visible: Dock.border; icon: "opacity"; label: "Border opacity"; option: "borderOpacity"; format: v => Math.round(v * 100) + "%" }
                DockSlider { visible: !Dock.glassActive; icon: "blur_circular"; label: "Shadow glow"; option: "shadowGlowRadius"; format: v => v.toFixed(1) + " px" }
                DockSlider { visible: !Dock.glassActive; icon: "gradient"; label: "Shadow spread"; option: "shadowSpread"; format: v => v.toFixed(2) }
                DockSlider { icon: "vertical_align_bottom"; label: "Screen gap"; option: "edgeGap" }
                DockSlider { icon: "swipe_up"; label: "Reveal area"; option: "revealStrip"; last: true }
            }

            Item { width: 1; height: 4 }

            SectionTitle {
                title: "Pinned apps"
                subtitle: "Separators group apps. Also editable from the Dock: right-click an icon, or drag to reorder."
            }

            DockPinnedApps { width: parent.width }

            Item { width: 1; height: 4 }

            SectionTitle { title: "Screens" }

            SettingsCard {
                Repeater {
                    model: Quickshell.screens

                    SettingsRow {
                        required property var modelData
                        required property int index
                        icon: "monitor"
                        label: modelData.name
                        last: index === Quickshell.screens.length - 1
                        Toggle {
                            checked: !Dock.hiddenScreens.includes(modelData.name)
                            onToggled: v => Dock.setShownOn(modelData.name, v)
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }

            SectionTitle {
                title: "Presets"
                subtitle: "Copy every Dock setting to the clipboard as text, or paste one back. Pinned apps and screen choices stay per machine."
            }

            Row {
                spacing: 8
                Chip { text: "Copy settings"; inactiveTint: Colors.surfaceHigh; onClicked: Dock.copyPreset() }
                Chip { text: "Paste settings"; inactiveTint: Colors.surfaceHigh; onClicked: Dock.pastePreset() }
            }

            StyledText {
                visible: Dock.presetStatus !== ""
                text: Dock.presetStatus
                font.pixelSize: Config.fontSize - 1
                color: Colors.subtext
            }

            Item { width: 1; height: 4 }

            PrimaryButton {
                width: parent.width
                icon: "restart_alt"
                text: "Reset Dock Settings"
                onClicked: Dock.resetOptions()
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.6
                font.pixelSize: Config.fontSize - 2
                text: "Restores defaults for everything above. Pinned apps and screen choices are kept."
            }
        }
    }
}
