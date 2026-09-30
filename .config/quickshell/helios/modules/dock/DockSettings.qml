import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Settings > Dock — visibility, hiding behavior, icon size, and which
// screens show the Dock.
Item {
    id: root

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    component SettingsCard: Rectangle {
        default property alias content: inner.children

        width: parent ? parent.width : 0
        implicitHeight: inner.implicitHeight
        height: implicitHeight
        radius: Colors.radiusLarge
        color: Colors.surfaceHigh

        Column {
            id: inner
            width: parent.width
        }
    }

    // Row inside a card: icon + label on the left, a control on the right,
    // hairline below unless last.
    component CardRow: Item {
        id: cardRow
        default property alias control: controlSlot.children
        property string icon: ""
        property string label: ""
        property bool last: false

        width: parent ? parent.width : 0
        height: 44

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            MaterialIcon { icon: cardRow.icon; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: cardRow.label; anchors.verticalCenter: parent.verticalCenter }
        }

        Item {
            id: controlSlot
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }

        Rectangle {
            visible: !cardRow.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.bottom: parent.bottom
            height: 1
            color: Colors.overlay
            opacity: 0.15
        }
    }

    // Slider row inside a card: icon + label, slider, formatted value.
    component SliderRow: Item {
        id: sliderRow
        property string icon: ""
        property string label: ""
        // Option key in Dock.options; range and value come from there.
        property string option: ""
        property real value: Dock[sliderRow.option]
        property real from: Dock.range(sliderRow.option)[0]
        property real to: Dock.range(sliderRow.option)[1]
        property var format: v => Math.round(v) + " px"
        property bool last: false

        width: parent ? parent.width : 0
        height: 48

        Row {
            id: sliderLabel
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            spacing: 10

            MaterialIcon { icon: sliderRow.icon; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: sliderRow.label; anchors.verticalCenter: parent.verticalCenter }
        }

        Slider {
            anchors.left: sliderLabel.right
            anchors.right: valueLabel.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            label: sliderRow.label
            trackColor: Colors.surface
            value: sliderRow.value - sliderRow.from
            maxValue: sliderRow.to - sliderRow.from
            onMoved: v => Dock.setOption(sliderRow.option, sliderRow.from + v)
        }

        StyledText {
            id: valueLabel
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            horizontalAlignment: Text.AlignRight
            text: sliderRow.format(sliderRow.value)
            color: Colors.subtext
        }

        Rectangle {
            visible: !sliderRow.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.bottom: parent.bottom
            height: 1
            color: Colors.overlay
            opacity: 0.15
        }
    }

    // Toggle row bound to a boolean Dock option.
    component OptionToggle: CardRow {
        id: optionToggle
        property string option: ""
        Toggle { checked: Dock[optionToggle.option]; onToggled: v => Dock.setOption(optionToggle.option, v) }
    }

    // Row with a SegmentedControl bound to a choice Dock option.
    component OptionChoice: CardRow {
        id: optionChoice
        property string option: ""
        property var choices: []
        SegmentedControl {
            implicitHeight: 32
            model: optionChoice.choices
            currentValue: Dock[optionChoice.option]
            onActivated: v => Dock.setOption(optionChoice.option, v)
        }
    }

    component SectionTitle: Column {
        property string title: ""
        property string subtitle: ""
        width: parent ? parent.width : 0
        spacing: 2

        StyledText { font.bold: true; text: parent.title }
        StyledText {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            opacity: 0.6
            font.pixelSize: Config.fontSize - 2
            text: parent.subtitle
        }
    }

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
            OptionToggle { icon: "dock_to_bottom"; label: "Show Dock"; option: "enabled"; last: true }
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
                OptionChoice {
                    icon: "dock_to_bottom"
                    label: "Position"
                    option: "position"
                    choices: [
                        { value: "left", label: "Left" },
                        { value: "bottom", label: "Bottom" },
                        { value: "right", label: "Right" }
                    ]
                }
                OptionChoice {
                    icon: "visibility_off"
                    label: "Hide"
                    option: "autohide"
                    choices: [
                        { value: "intellihide", label: "Smart" },
                        { value: "always", label: "Always" },
                        { value: "never", label: "Never" }
                    ]
                }
                SliderRow {
                    visible: Dock.autohide !== "never"
                    icon: "timer"
                    label: "Hide delay"
                    option: "hideDelay"
                    format: v => Math.round(v) + " ms"
                }
                OptionToggle { icon: "apps"; label: "Show running apps"; option: "showRunning" }
                OptionToggle { icon: "history"; label: "Show recent apps"; option: "showRecents" }
                SliderRow {
                    visible: Dock.showRecents
                    icon: "history"
                    label: "Recent apps"
                    option: "recentCount"
                    format: v => Math.round(v)
                }
                OptionChoice {
                    icon: "select_window"
                    label: "Show windows from"
                    option: "runningScope"
                    choices: [
                        { value: "all", label: "All" },
                        { value: "monitor", label: "This screen" },
                        { value: "workspace", label: "Workspace" }
                    ]
                }
                OptionToggle { icon: "web_asset"; label: "Window previews"; option: "previews"; last: true }
            }

            Item { width: 1; height: 4 }

            SectionTitle {
                title: "Clicking"
                subtitle: "Minimized windows move to a hidden workspace; click the app again to bring them back."
            }

            SettingsCard {
                OptionChoice {
                    icon: "left_click"
                    label: "Click focused app"
                    option: "focusedClick"
                    choices: [
                        { value: "cycle", label: "Cycle" },
                        { value: "minimize", label: "Minimize" },
                        { value: "none", label: "Nothing" }
                    ]
                }
                OptionToggle { icon: "swap_vert"; label: "Scroll to cycle windows"; option: "scrollCycle" }
                OptionChoice {
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
                OptionToggle { icon: "animation"; label: "Bounce while launching"; option: "launchBounce" }
                OptionToggle { icon: "label"; label: "App name on hover"; option: "showTooltips" }
                SliderRow {
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
                OptionToggle { icon: "fiber_manual_record"; label: "Running indicators"; option: "showIndicators" }
                OptionToggle { icon: "notifications"; label: "Notification badges"; option: "showBadges" }
                OptionToggle { icon: "grid_view"; label: "All Applications button"; option: "showAppsButton" }
                OptionToggle { icon: "settings"; label: "Settings button"; option: "showSettingsButton" }
                OptionToggle { icon: "delete"; label: "Trash"; option: "showTrash" }
                OptionToggle { icon: "zoom_in"; label: "Magnify on hover"; option: "magnify"; last: !Dock.magnify }
                SliderRow {
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
                SliderRow { icon: "photo_size_select_large"; label: "Icon size"; option: "iconSize" }
                SliderRow { icon: "space_bar"; label: "Icon spacing"; option: "iconSpacing" }
                SliderRow { icon: "padding"; label: "Edge padding"; option: "edgePadding"; last: true }
            }

            Item { width: 1; height: 4 }

            SectionTitle { title: "Appearance" }

            SettingsCard {
                OptionChoice {
                    icon: "blur_on"
                    label: "Liquid glass"
                    option: "glass"
                    choices: [
                        { value: "follow", label: "Shell" },
                        { value: "on", label: "On" },
                        { value: "off", label: "Off" }
                    ]
                }
                SliderRow { icon: "opacity"; label: "Background"; option: "backgroundOpacity"; format: v => Math.round(v * 100) + "%" }
                SliderRow { icon: "rounded_corner"; label: "Corner radius"; option: "cornerRadius" }
                SliderRow { icon: "vertical_align_bottom"; label: "Screen gap"; option: "edgeGap" }
                SliderRow { icon: "swipe_up"; label: "Reveal area"; option: "revealStrip"; last: true }
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

                    CardRow {
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
