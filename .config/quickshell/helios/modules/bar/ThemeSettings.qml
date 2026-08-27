import QtQuick
import "../../services"
import "../../components"

// Apple Settings-style theme selector — grouped sections with clear
// hierarchy, rounded card containers, and refined preset swatches.
Item {
    id: root

    implicitWidth: 360
    implicitHeight: col.implicitHeight

    property bool themeGridOpen: false
    property bool schemeListOpen: false

    readonly property var schemeDescriptions: ({
        "scheme-tonal-spot": "Balanced, muted accent — the default.",
        "scheme-vibrant": "Saturated colors pulled from the wallpaper.",
        "scheme-expressive": "Wider hue range for stronger contrast.",
        "scheme-fruit-salad": "Multiple accent hues across the UI.",
        "scheme-rainbow": "Maximum hue variety, low saturation.",
        "scheme-content": "Follows the dominant wallpaper color closely.",
        "scheme-fidelity": "Closest match to the source image.",
        "scheme-monochrome": "Single hue, varied by lightness only.",
        "scheme-neutral": "Minimal saturation across all surfaces."
    })

    Column {
        id: col
        width: parent.width
        spacing: 20

        // ─── Header ──────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 4

            StyledText {
                text: "Appearance"
                font.pixelSize: Config.fontSize + 4
                font.weight: Font.Bold
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Colors.subtext
                font.pixelSize: Config.fontSize - 1
                text: Themes.currentLabel() + " · Also applies to GTK, Qt, Ghostty, btop, Neovim, Zed, Bat"
            }
        }

        // ─── Theme section ────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 10

            StyledText {
                text: "Theme"
                font.pixelSize: Config.fontSize - 1
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                color: Colors.subtext
            }

            // Current theme, collapsed by default — click to reveal the grid
            HoverRow {
                width: parent.width
                height: 44
                highlighted: root.themeGridOpen
                onClicked: root.themeGridOpen = !root.themeGridOpen

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: Colors.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        StyledText { text: Themes.currentLabel(); font.weight: Font.Medium }
                        StyledText {
                            text: Themes.presetOrder.length + " themes installed"
                            font.pixelSize: Config.fontSize - 3
                            color: Colors.subtext
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    StyledText { text: "Change"; color: Colors.accent; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                    MaterialIcon {
                        icon: root.themeGridOpen ? "expand_less" : "chevron_right"
                        font.pixelSize: 15
                        color: Colors.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Theme grid — 3 columns of rounded cards with color preview
            Grid {
                width: parent.width
                columns: 3
                spacing: 8
                visible: root.themeGridOpen

                Repeater {
                    model: Themes.presetOrder

                    Rectangle {
                        id: card
                        required property string modelData
                        readonly property var palette: Themes.presets[modelData]
                        readonly property bool active: Themes.mode === "preset" && Themes.presetName === modelData

                        width: (parent.width - 16) / 3
                        height: 64
                        radius: 12
                        color: card.palette.surface
                        border.width: active ? 2 : 0
                        border.color: Colors.accent
                        clip: true

                        // Swatch strip — background/surfaceHigh/accent, a real
                        // preview instead of a single dot, pinned to the card edge
                        Row {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 5
                            Rectangle { width: parent.width / 3; height: parent.height; color: card.palette.background }
                            Rectangle { width: parent.width / 3; height: parent.height; color: card.palette.surfaceHigh }
                            Rectangle { width: parent.width / 3; height: parent.height; color: card.palette.accent }
                        }

                        // Subtle inner highlight when active
                        Rectangle {
                            visible: card.active
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                            color: "transparent"
                            border.width: 0.5
                            border.color: Qt.rgba(card.palette.text.r, card.palette.text.g, card.palette.text.b, 0.1)
                        }

                        // Hover overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: card.palette.text
                            opacity: cardHover.hovered && !card.active ? 0.06 : 0

                            Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                        }

                        HoverHandler { id: cardHover }

                        Column {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 3
                            spacing: 4

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: card.palette.accent
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: card.palette.label
                                color: card.palette.text
                                font.pixelSize: Config.fontSize - 3
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                width: card.width - 10
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        // Checkmark badge when active
                        Rectangle {
                            visible: card.active
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            width: 15
                            height: 15
                            radius: 7.5
                            color: Colors.accent

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "check"
                                font.pixelSize: 10
                                color: Colors.accentText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Themes.applyPreset(card.modelData)
                        }
                    }
                }
            }
        }

        // ─── Match wallpaper colors ───────────────────────────────────────
        Column {
            width: parent.width
            spacing: 8

            Row {
                width: parent.width

                Column {
                    width: parent.width - matchToggle.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    StyledText {
                        font.weight: Font.Medium
                        text: Themes.generating ? "Generating…" : "Match wallpaper colors"
                    }
                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: Colors.subtext
                        font.pixelSize: Config.fontSize - 3
                        text: "Generates the palette from your current wallpaper."
                    }
                }

                Toggle {
                    id: matchToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Themes.mode === "dynamic"
                    onToggled: v => v ? Themes.applyDynamic() : Themes.applyPreset(Themes.presetName)
                }
            }

            StyledText {
                visible: Themes.lastError.length > 0
                width: parent.width
                wrapMode: Text.WordWrap
                color: Colors.danger
                font.pixelSize: Config.fontSize - 2
                text: Themes.lastError
            }
        }

        // ─── Dark mode ────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 10

            Row {
                width: parent.width

                StyledText {
                    width: parent.width - darkToggle.width
                    anchors.verticalCenter: parent.verticalCenter
                    font.weight: Font.Medium
                    text: "Dark mode"
                }

                Toggle {
                    id: darkToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Themes.dynamicDark
                    onToggled: v => Themes.setDynamicMode(v)
                }
            }

            // Palette scheme — collapsed by default
            HoverRow {
                width: parent.width
                height: 32
                highlighted: root.schemeListOpen
                onClicked: root.schemeListOpen = !root.schemeListOpen

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    MaterialIcon {
                        icon: root.schemeListOpen ? "expand_less" : "chevron_right"
                        font.pixelSize: 13
                        opacity: 0.6
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: "Palette scheme"
                        color: Colors.subtext
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2
                visible: root.schemeListOpen

                Repeater {
                    model: Themes.schemeOptions

                    HoverRow {
                        id: schemeRow
                        required property var modelData
                        width: parent.width
                        height: 46
                        onClicked: Themes.setPaletteScheme(modelData.value)

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                color: "transparent"
                                border.width: 1.5
                                border.color: Themes.paletteScheme === schemeRow.modelData.value ? Colors.accent : Colors.overlay

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 7
                                    height: 7
                                    radius: 3.5
                                    color: Colors.accent
                                    visible: Themes.paletteScheme === schemeRow.modelData.value
                                }
                            }

                            Column {
                                width: parent.width - 24
                                spacing: 1

                                StyledText {
                                    text: schemeRow.modelData.label
                                    font.weight: Font.Medium
                                    color: Themes.paletteScheme === schemeRow.modelData.value ? Colors.accent : Colors.text
                                }
                                StyledText {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: Config.fontSize - 3
                                    color: Colors.subtext
                                    text: root.schemeDescriptions[schemeRow.modelData.value] || ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
